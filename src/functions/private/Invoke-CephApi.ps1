function Invoke-CephApi {
    <#
    .SYNOPSIS
        Internal function to invoke Ceph Dashboard REST API endpoints.

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

    .EXAMPLE
        Invoke-CephApi -Endpoint '/api/health/full'

    .EXAMPLE
        Invoke-CephApi -Endpoint '/api/pool' -Method POST -Body @{ pool = 'mypool'; pg_num = 128 }
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
        [string]$ContentType = 'application/json'
    )

    if (-not $script:CephSession) {
        throw 'Not connected to Ceph cluster. Use Connect-Ceph first.'
    }

    $session = $script:CephSession

    # Check if token needs refresh
    if ($session.TokenExpiry -and (Get-Date) -ge $session.TokenExpiry.AddMinutes(-5)) {
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
            }
            if ($session.SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
                $refreshParams['SkipCertificateCheck'] = $true
            }
            $refreshResponse = Invoke-RestMethod @refreshParams
            $session.Token = $refreshResponse.token
            $session.TokenExpiry = (Get-Date).AddHours(1)
            Write-Verbose 'Token refreshed successfully'
        }
        catch {
            Write-Warning "Token refresh failed: $_. You may need to reconnect."
        }
    }

    $uri = "$($session.BaseUri)$Endpoint"
    Write-Verbose "Invoking $Method $uri"

    # Determine API version based on endpoint (v2.0 endpoints)
    $v2Endpoints = @('/api/block/', '/api/nvmeof/', '/api/smb/', '/api/rgw/')
    $apiVersion = '1.0'
    foreach ($v2Ep in $v2Endpoints) {
        if ($Endpoint.StartsWith($v2Ep)) {
            $apiVersion = '2.0'
            break
        }
    }

    $headers = @{
        Authorization = "Bearer $($session.Token)"
        Accept        = "application/vnd.ceph.api.v$apiVersion+json"
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

            try {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                $reader.Close()

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
