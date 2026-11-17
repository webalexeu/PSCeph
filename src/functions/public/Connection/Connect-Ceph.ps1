function Connect-Ceph {
    <#
    .SYNOPSIS
        Establishes a connection to a Ceph Dashboard API

    .DESCRIPTION
        Authenticates to the Ceph Dashboard REST API and stores the session token
        for subsequent API calls. The connection persists until Disconnect-Ceph
        is called or the PowerShell session ends.

        Two authentication methods are supported: username/password (the
        Dashboard's built-in local auth), and the OIDC device code grant (for
        clusters with 'ceph dashboard sso enable oauth2' configured - works
        against any OIDC provider that supports RFC 8628, e.g. authentik,
        Keycloak, Okta, Entra ID).

        Which one to use is normally auto-detected: Connect-Ceph calls the
        Dashboard's own unauthenticated /api/auth/check endpoint, which reveals
        the configured backend, and proceeds accordingly - prompting for
        credentials, or running the device code flow. Use -Credential or -Sso
        to skip that probe and pick a method explicitly (e.g. if the probe
        itself isn't reachable, or to force one method when both are enabled).

    .PARAMETER Server
        The hostname or IP address of the Ceph Dashboard server.

    .PARAMETER Port
        The port number for the Ceph Dashboard. Defaults to 8443.

    .PARAMETER Credential
        PSCredential for local (username/password) authentication. Supplying
        this skips auto-detection and forces the local auth flow. If omitted
        and auto-detection resolves to local auth, you'll be prompted.

    .PARAMETER Sso
        Forces the OIDC device code flow, skipping auto-detection. Only needed
        if the /api/auth/check probe itself can't be used (e.g. blocked by a
        firewall) - normally Connect-Ceph detects this on its own.

    .PARAMETER OidcIssuerUrl
        The OIDC issuer base URL of your identity provider (e.g. an authentik
        application's issuer, such as https://auth.example.com/application/o/ceph/).
        Required when using OIDC - Ceph does not expose this over its API, so
        it must be supplied by the caller.

    .PARAMETER OidcClientId
        The OAuth2 client ID registered with the OIDC provider for this device
        flow. Required when using OIDC, for the same reason as -OidcIssuerUrl.

    .PARAMETER OidcClientSecret
        Optional client secret as a SecureString. Only needed if your provider
        requires one even for the device code grant.

    .PARAMETER OidcScope
        Space-separated OAuth2 scopes to request. Defaults to 'openid'.

    .PARAMETER OidcTokenClaim
        Which issued token to present to the Ceph Dashboard as X-Access-Token:
        'AccessToken' (default) or 'IdToken'. Pick whichever one your provider puts
        the role claims on (see 'ceph dashboard sso enable oauth2 --roles_path').

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation. Use with caution in production environments.

    .EXAMPLE
        Connect-Ceph -Server 'ceph-mgr.local'
        Detects the Dashboard's configured auth method automatically and
        prompts for whatever it needs (a credential, or runs the OIDC device
        flow if -OidcIssuerUrl/-OidcClientId were also given).

    .EXAMPLE
        Connect-Ceph -Server 'ceph-mgr.local' -Credential (Get-Credential)
        Skips auto-detection and connects using local username/password auth.

    .EXAMPLE
        Connect-Ceph -Server 'ceph-mgr.local' -OidcIssuerUrl 'https://auth.example.com/application/o/ceph/' -OidcClientId 'ceph-dashboard'
        Auto-detects OIDC is configured (or pass -Sso to skip the probe) and
        runs the device code grant - prints a URL and code to approve in a
        browser, on any device.

    .OUTPUTS
        PSCustomObject representing the connection information.

    .LINK
        https://psmodule.io/PSCeph/Functions/Connection/Connect-Ceph/
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 8443,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [switch]$Sso,

        [Parameter()]
        [string]$OidcIssuerUrl,

        [Parameter()]
        [string]$OidcClientId,

        [Parameter()]
        [securestring]$OidcClientSecret,

        [Parameter()]
        [string]$OidcScope = 'openid',

        [Parameter()]
        [ValidateSet('AccessToken', 'IdToken')]
        [string]$OidcTokenClaim = 'AccessToken',

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    if ($Credential -and $Sso) {
        throw '-Credential and -Sso are mutually exclusive - pick one authentication method.'
    }

    $baseUri = "https://${Server}:${Port}"
    Write-Verbose "Connecting to Ceph Dashboard at $baseUri"

    if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -lt 6) {
        # PowerShell 5.1 compatibility - this is process-wide, so set it once up
        # front and every call below (probe, OIDC, or local auth) benefits from it.
        if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
            Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
        }
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    }

    $useSso = $Sso.IsPresent
    if (-not $Credential -and -not $Sso) {
        Write-Verbose 'Probing the Dashboard for its configured authentication method...'
        $detected = Resolve-CephAuthMethod -BaseUri $baseUri -SkipCertificateCheck:$SkipCertificateCheck.IsPresent
        Write-Verbose "Detected authentication method: $detected"

        switch ($detected) {
            'OAuth2' { $useSso = $true }
            'SAML2' {
                throw "This Dashboard is configured for SAML2 SSO, which requires a browser - Connect-Ceph only" +
                " supports local auth or the OIDC device code grant (OAuth2). Pass -Credential if local auth is" +
                " also permitted on this cluster, or switch the cluster to 'ceph dashboard sso enable oauth2' instead."
            }
            'Local' { $useSso = $false }
            default {
                throw "Could not determine the Dashboard's authentication method at $baseUri. Pass -Credential or -Sso to pick one explicitly."
            }
        }
    }

    if ($useSso) {
        if (-not $OidcIssuerUrl -or -not $OidcClientId) {
            throw "This Dashboard requires OIDC SSO (or -Sso was specified), but -OidcIssuerUrl and -OidcClientId" +
            " were not provided. Ceph does not expose these over its API - supply the issuer URL and client ID" +
            ' registered with your identity provider.'
        }

        $plainClientSecret = $null
        if ($OidcClientSecret) {
            $plainClientSecret = [System.Net.NetworkCredential]::new('', $OidcClientSecret).Password
        }

        $deviceFlowParams = @{
            IssuerUrl            = $OidcIssuerUrl
            ClientId             = $OidcClientId
            Scope                = $OidcScope
            SkipCertificateCheck = $SkipCertificateCheck
        }
        if ($plainClientSecret) {
            $deviceFlowParams['ClientSecret'] = $plainClientSecret
        }

        $tokens = Invoke-CephOidcDeviceCodeFlow @deviceFlowParams

        $presentedToken = $tokens.AccessToken
        if ($OidcTokenClaim -eq 'IdToken') {
            $presentedToken = $tokens.IdToken
        }
        if (-not $presentedToken) {
            throw "OIDC provider did not return a $OidcTokenClaim."
        }

        $claims = ConvertFrom-JwtPayload -Token $presentedToken
        $displayName = $claims.sub
        if ($claims.preferred_username) {
            $displayName = $claims.preferred_username
        }

        $tokenExpiry = (Get-Date).AddMinutes(5)
        if ($tokens.ExpiresIn) {
            $tokenExpiry = (Get-Date).AddSeconds([int]$tokens.ExpiresIn)
        }

        $script:CephSession = [PSCustomObject]@{
            PSTypeName           = 'PSCeph.Connection'
            Server               = $Server
            Port                 = $Port
            BaseUri              = $baseUri
            AuthMethod           = 'OIDC'
            Token                = $presentedToken
            RefreshToken         = $tokens.RefreshToken
            TokenEndpoint        = $tokens.TokenEndpoint
            OidcClientId         = $OidcClientId
            OidcClientSecret     = $OidcClientSecret
            OidcScope            = $OidcScope
            OidcTokenClaim       = $OidcTokenClaim
            TokenExpiry          = $tokenExpiry
            Username             = $displayName
            SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            ConnectedAt          = Get-Date
            Permissions          = $null
        }

        # Confirm the Dashboard actually accepts this token before declaring success.
        try {
            $null = Invoke-CephApi -Endpoint '/api/health/minimal'
        }
        catch {
            $script:CephSession = $null
            throw "Ceph Dashboard rejected the OIDC token: $_. Confirm 'ceph dashboard sso enable oauth2' is configured and the token carries the expected role claims."
        }

        Write-Verbose "Successfully connected to Ceph Dashboard via OIDC as $displayName"

        return [PSCustomObject]@{
            PSTypeName  = 'PSCeph.ConnectionInfo'
            Server      = $Server
            Port        = $Port
            Username    = $displayName
            ConnectedAt = $script:CephSession.ConnectedAt
            Permissions = $script:CephSession.Permissions
        }
    }

    # --- Local auth ---
    if (-not $Credential) {
        $Credential = Get-Credential -Message "Ceph Dashboard credentials for $Server"
    }

    $authUri = "$baseUri/api/auth"

    $authBody = @{
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    } | ConvertTo-Json -Compress

    $params = @{
        Uri         = $authUri
        Method      = 'POST'
        Body        = $authBody
        ContentType = 'application/json'
        Headers     = @{ Accept = 'application/vnd.ceph.api.v1.0+json' }
    }

    if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
        $params['SkipCertificateCheck'] = $true
    }

    try {
        $response = Invoke-RestMethod @params
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            throw "Failed to connect to Ceph Dashboard at $baseUri. Status: $statusCode. Error: $errorMessage"
        }
        throw "Failed to connect to Ceph Dashboard at $baseUri. Error: $errorMessage"
    }

    if (-not $response.token) {
        throw 'Authentication succeeded but no token was returned.'
    }

    # Calculate token expiry from response or use default
    $tokenExpiry = if ($response.token_expiry) {
        # API returns expiry as Unix timestamp
        [DateTimeOffset]::FromUnixTimeSeconds($response.token_expiry).LocalDateTime
    }
    elseif ($response.ttl) {
        # API returns TTL in seconds
        (Get-Date).AddSeconds($response.ttl)
    }
    else {
        # Default fallback (Ceph Dashboard default is typically 8 hours)
        (Get-Date).AddHours(8)
    }

    $script:CephSession = [PSCustomObject]@{
        PSTypeName           = 'PSCeph.Connection'
        Server               = $Server
        Port                 = $Port
        BaseUri              = $baseUri
        AuthMethod           = 'Local'
        Token                = $response.token
        TokenExpiry          = $tokenExpiry
        Username             = $Credential.UserName
        SkipCertificateCheck = $SkipCertificateCheck.IsPresent
        ConnectedAt          = Get-Date
        Permissions          = $response.permissions
    }

    Write-Verbose "Successfully connected to Ceph Dashboard as $($Credential.UserName)"

    [PSCustomObject]@{
        PSTypeName  = 'PSCeph.ConnectionInfo'
        Server      = $Server
        Port        = $Port
        Username    = $Credential.UserName
        ConnectedAt = $script:CephSession.ConnectedAt
        Permissions = $response.permissions
    }
}
