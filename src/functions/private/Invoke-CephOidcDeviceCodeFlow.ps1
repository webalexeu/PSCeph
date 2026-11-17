function Invoke-CephOidcDeviceCodeFlow {
    <#
    .SYNOPSIS
        Performs the OAuth2 device authorization grant (RFC 8628) against an OIDC provider.

    .DESCRIPTION
        Discovers the provider's device_authorization_endpoint and token_endpoint via
        OpenID Connect discovery, requests a device code, prints the verification URL
        and user code, then polls the token endpoint until the user approves (or the
        request expires or is denied). Nothing here is provider-specific - this works
        against any RFC 8628-compliant OIDC provider (authentik, Keycloak, Okta, Entra
        ID, Auth0, ...).

    .PARAMETER IssuerUrl
        The OIDC issuer base URL (e.g. https://auth.example.com/application/o/ceph/).

    .PARAMETER ClientId
        The OAuth2 client ID registered with the provider for this device flow.

    .PARAMETER ClientSecret
        Optional client secret, for providers that require one even for the device
        code grant.

    .PARAMETER Scope
        Space-separated OAuth2 scopes to request. Defaults to 'openid'.

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation against the IdP (PowerShell 6+ only; on 5.1
        this relies on the process-wide certificate policy set by the caller).

    .OUTPUTS
        PSCustomObject with AccessToken, IdToken, RefreshToken, ExpiresIn, TokenEndpoint.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$IssuerUrl,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [Parameter()]
        [string]$ClientSecret,

        [Parameter()]
        [string]$Scope = 'openid',

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    $restParams = @{}
    if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
        $restParams['SkipCertificateCheck'] = $true
    }

    $discoveryUri = $IssuerUrl.TrimEnd('/') + '/.well-known/openid-configuration'
    Write-Verbose "Discovering OIDC endpoints at $discoveryUri"
    try {
        $discovery = Invoke-RestMethod -Uri $discoveryUri -Method GET @restParams
    }
    catch {
        throw "Failed to retrieve OIDC discovery document from $discoveryUri. Error: $_"
    }

    if (-not $discovery.device_authorization_endpoint) {
        throw "Provider at $IssuerUrl does not advertise a device_authorization_endpoint - it does not support the device code grant (RFC 8628)."
    }
    if (-not $discovery.token_endpoint) {
        throw "Provider at $IssuerUrl does not advertise a token_endpoint."
    }

    $deviceBody = @{
        client_id = $ClientId
        scope     = $Scope
    }
    if ($ClientSecret) {
        $deviceBody['client_secret'] = $ClientSecret
    }

    Write-Verbose "Requesting device code from $($discovery.device_authorization_endpoint)"
    $deviceResponse = Invoke-RestMethod -Uri $discovery.device_authorization_endpoint -Method POST `
        -Body $deviceBody -ContentType 'application/x-www-form-urlencoded' @restParams

    $verificationUrl = $deviceResponse.verification_uri
    if ($deviceResponse.verification_uri_complete) {
        $verificationUrl = $deviceResponse.verification_uri_complete
    }

    $prompt = "To sign in, open the following URL and approve the request:`n  $verificationUrl"
    if (-not $deviceResponse.verification_uri_complete) {
        $prompt += "`nUser code: $($deviceResponse.user_code)"
    }
    Write-Information $prompt -InformationAction Continue

    $interval = 5
    if ($deviceResponse.interval) {
        $interval = [int]$deviceResponse.interval
    }
    $expiresInSeconds = 300
    if ($deviceResponse.expires_in) {
        $expiresInSeconds = [int]$deviceResponse.expires_in
    }
    $expiresAt = (Get-Date).AddSeconds($expiresInSeconds)

    $tokenBody = @{
        grant_type  = 'urn:ietf:params:oauth:grant-type:device_code'
        device_code = $deviceResponse.device_code
        client_id   = $ClientId
    }
    if ($ClientSecret) {
        $tokenBody['client_secret'] = $ClientSecret
    }

    while ((Get-Date) -lt $expiresAt) {
        Start-Sleep -Seconds $interval

        try {
            $tokenResponse = Invoke-RestMethod -Uri $discovery.token_endpoint -Method POST `
                -Body $tokenBody -ContentType 'application/x-www-form-urlencoded' @restParams

            Write-Verbose 'Device authorized - token issued.'
            return [PSCustomObject]@{
                AccessToken   = $tokenResponse.access_token
                IdToken       = $tokenResponse.id_token
                RefreshToken  = $tokenResponse.refresh_token
                ExpiresIn     = $tokenResponse.expires_in
                TokenEndpoint = $discovery.token_endpoint
            }
        }
        catch {
            $errBody = $null
            if ($_.ErrorDetails.Message) {
                $errBody = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            }

            switch ($errBody.error) {
                'authorization_pending' { continue }
                'slow_down' {
                    $interval += 5
                    continue
                }
                'access_denied' { throw 'Device authorization was denied by the user.' }
                'expired_token' { throw 'Device code expired before authorization completed.' }
                default {
                    if ($errBody.error) {
                        $msg = $errBody.error
                        if ($errBody.error_description) {
                            $msg = $errBody.error_description
                        }
                        throw "Device code token request failed: $msg"
                    }
                    throw
                }
            }
        }
    }

    throw 'Device authorization timed out before the user approved the request.'
}
