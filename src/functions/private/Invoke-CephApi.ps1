function Invoke-CephApi {
    <#
    .SYNOPSIS
        Internal function to invoke Ceph Dashboard REST API endpoints

    .DESCRIPTION
        Handles all REST API calls to the Ceph Dashboard with automatic token management,
        error handling, and response processing.

    .PARAMETER Endpoint
        The API endpoint path (e.g., '/api/health/full').

    .PARAMETER Method
        The HTTP method to use. Defaults to GET.

    .PARAMETER Body
        Optional request body for POST/PUT/PATCH requests.

    .PARAMETER ContentType
        Content type for the request. Defaults to 'application/json'.

    .PARAMETER ApiVersion
        API version to use. If not specified, version is auto-detected based on endpoint.
        Valid values: '0.1', '1.0', '2.0'

    .EXAMPLE
        Invoke-CephApi -Endpoint '/api/health/full'

    .EXAMPLE
        Invoke-CephApi -Endpoint '/api/pool' -Method POST -Body @{ pool = 'mypool'; pg_num = 128 }

    .EXAMPLE
        Invoke-CephApi -Endpoint '/api/cluster' -ApiVersion '0.1'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Endpoint,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [string]$ContentType = 'application/json',

        [Parameter()]
        [ValidateSet('0.1', '1.0', '2.0')]
        [string]$ApiVersion
    )

    if (-not $script:CephSession) {
        throw 'Not connected to Ceph cluster. Use Connect-Ceph first.'
    }

    $session = $script:CephSession

    # Check if token needs refresh
    if ($session.TokenExpiry -and (Get-Date) -ge $session.TokenExpiry.AddMinutes(-5)) {
        if ($session.AuthMethod -eq 'OIDC') {
            if ($session.RefreshToken -and $session.TokenEndpoint) {
                Write-Verbose 'OIDC token expiring soon, attempting refresh...'
                try {
                    $refreshBody = @{
                        grant_type    = 'refresh_token'
                        refresh_token = $session.RefreshToken
                        client_id     = $session.OidcClientId
                    }
                    if ($session.OidcClientSecret) {
                        $refreshBody['client_secret'] = [System.Net.NetworkCredential]::new('', $session.OidcClientSecret).Password
                    }
                    $refreshParams = @{
                        Uri         = $session.TokenEndpoint
                        Method      = 'POST'
                        Body        = $refreshBody
                        ContentType = 'application/x-www-form-urlencoded'
                    }
                    if ($session.SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
                        $refreshParams['SkipCertificateCheck'] = $true
                    }
                    $tokenResponse = Invoke-RestMethod @refreshParams
                    $session.Token = if ($session.OidcTokenClaim -eq 'IdToken') { $tokenResponse.id_token } else { $tokenResponse.access_token }
                    if ($tokenResponse.refresh_token) {
                        $session.RefreshToken = $tokenResponse.refresh_token
                    }
                    $session.TokenExpiry = if ($tokenResponse.expires_in) {
                        (Get-Date).AddSeconds([int]$tokenResponse.expires_in)
                    }
                    else {
                        (Get-Date).AddMinutes(5)
                    }
                    Write-Verbose 'OIDC token refreshed successfully'
                }
                catch {
                    Write-Warning "OIDC token refresh failed: $_. You may need to reconnect with Connect-Ceph."
                }
            }
            else {
                Write-Warning 'OIDC token is expiring and no refresh token is available. Reconnect with Connect-Ceph.'
            }
        }
        else {
            Write-Verbose 'Token expiring soon, attempting refresh...'
            try {
                $refreshParams = @{
                    Uri         = "$($session.BaseUri)/api/auth/refresh"
                    Method      = 'POST'
                    Headers     = @{
                        Authorization = "Bearer $($session.Token)"
                        Accept        = 'application/vnd.ceph.api.v1.0+json'
                    }
                    ContentType = 'application/json'
                    Body        = '{}'
                }
                if ($session.SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
                    $refreshParams['SkipCertificateCheck'] = $true
                }
                $refreshResponse = Invoke-RestMethod @refreshParams
                $session.Token = $refreshResponse.token
                # Calculate token expiry from response or use default
                if ($refreshResponse.token_expiry) {
                    $session.TokenExpiry = [DateTimeOffset]::FromUnixTimeSeconds($refreshResponse.token_expiry).LocalDateTime
                }
                elseif ($refreshResponse.ttl) {
                    $session.TokenExpiry = (Get-Date).AddSeconds($refreshResponse.ttl)
                }
                else {
                    $session.TokenExpiry = (Get-Date).AddHours(8)
                }
                Write-Verbose 'Token refreshed successfully'
            }
            catch {
                Write-Warning "Token refresh failed: $_. You may need to reconnect."
            }
        }
    }

    $uri = "$($session.BaseUri)$Endpoint"
    Write-Verbose "Invoking $Method $uri"

    # Determine API version - use explicit parameter if provided, otherwise auto-detect
    $effectiveVersion = if ($ApiVersion) {
        $ApiVersion
    }
    else {
        # Auto-detect API version based on endpoint patterns
        # v0.1: /api/cluster (cluster installation status)
        # v2.0: /api/block/* (RBD), /api/crush_rule
        # v1.0: Default for all other endpoints (including /api/nvmeof/*, /api/smb/*, etc.)
        if ($Endpoint -eq '/api/cluster') {
            '0.1'
        }
        elseif ($Endpoint.StartsWith('/api/block/') -or $Endpoint -eq '/api/crush_rule') {
            '2.0'
        }
        else {
            '1.0'
        }
    }
    Write-Verbose "Using API version: $effectiveVersion"

    $headers = @{
        Accept = "application/vnd.ceph.api.v$effectiveVersion+json"
    }
    if ($session.AuthMethod -eq 'OIDC') {
        $headers['X-Access-Token'] = $session.Token
    }
    else {
        $headers['Authorization'] = "Bearer $($session.Token)"
    }

    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = $headers
    }

    if ($session.SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
        $params['SkipCertificateCheck'] = $true
    }

    if ($Body) {
        if ($Body -is [hashtable] -or $Body -is [psobject]) {
            $params['Body'] = $Body | ConvertTo-Json -Depth 10 -Compress
        }
        else {
            $params['Body'] = $Body
        }
        $params['ContentType'] = $ContentType
        Write-Verbose "Request body: $($params['Body'])"
    }

    try {
        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        $errorMessage = $_.Exception.Message
        $statusCode = $null

        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode

            # Try to extract error details from response body
            try {
                # PowerShell Core uses ErrorDetails, PS 5.1 uses GetResponseStream
                $responseBody = $null
                if ($_.ErrorDetails.Message) {
                    $responseBody = $_.ErrorDetails.Message
                }
                elseif ($_.Exception.Response.GetResponseStream) {
                    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $responseBody = $reader.ReadToEnd()
                    $reader.Close()
                }

                if ($responseBody) {
                    $errorDetail = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($errorDetail.detail) {
                        $errorMessage = $errorDetail.detail
                    }
                    elseif ($errorDetail.message) {
                        $errorMessage = $errorDetail.message
                    }
                }
            }
            catch {
                Write-Debug "Failed to parse error response: $_"
            }
        }

        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new("Ceph API Error ($statusCode): $errorMessage"),
            'CephApiError',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $uri
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}
