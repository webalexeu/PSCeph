function ConvertFrom-JwtPayload {
    <#
    .SYNOPSIS
        Decodes a JWT's payload claims without verifying its signature.

    .DESCRIPTION
        For display/session purposes only (e.g. showing which identity Connect-Ceph
        authenticated as). This mirrors how the Ceph Dashboard's own OAuth2 backend
        reads claims from these tokens - it does not verify signatures either, relying
        instead on the token only reaching the Dashboard through a trusted path
        (oauth2-proxy, or direct access in this module's case).

    .PARAMETER Token
        The JWT string.

    .OUTPUTS
        PSCustomObject of the decoded claims.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Token
    )

    $parts = $Token.Split('.')
    if ($parts.Count -lt 2) {
        throw 'Not a valid JWT (expected at least header.payload).'
    }

    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
    }

    $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
    $json | ConvertFrom-Json
}
