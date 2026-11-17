function Resolve-CephAuthMethod {
    <#
    .SYNOPSIS
        Detects which authentication backend a Ceph Dashboard is configured for.

    .DESCRIPTION
        Calls the unauthenticated POST /api/auth/check endpoint (no token supplied)
        and inspects the returned login_url. Ceph's own backend sets this to a
        protocol-specific, hardcoded value:
          - '#/login'            -> Local (username/password)
          - 'auth/oauth2/login'  -> OAuth2 SSO
          - 'auth/saml2/...'     -> SAML2 SSO
        (see services/auth/{auth,oauth2,saml2}.py's LOGIN_URL class attributes).
        This lets Connect-Ceph pick the right flow without the caller having to
        know or specify it up front.

    .PARAMETER BaseUri
        The Dashboard's base URI, e.g. https://ceph-mgr.local:8443.

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation.

    .OUTPUTS
        One of 'Local', 'OAuth2', 'SAML2', or 'Unknown'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    $params = @{
        Uri     = "$BaseUri/api/auth/check"
        Method  = 'POST'
        Headers = @{ Accept = 'application/vnd.ceph.api.v1.0+json' }
    }
    if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
        $params['SkipCertificateCheck'] = $true
    }

    try {
        $response = Invoke-RestMethod @params
    }
    catch {
        throw "Could not probe $BaseUri/api/auth/check to detect the authentication method: $_"
    }

    switch -Regex ($response.login_url) {
        '^auth/oauth2/login' { return 'OAuth2' }
        '^auth/saml2' { return 'SAML2' }
        '^#/login' { return 'Local' }
        default { return 'Unknown' }
    }
}
