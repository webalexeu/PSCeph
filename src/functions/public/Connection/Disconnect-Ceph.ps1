function Disconnect-Ceph {
    <#
    .SYNOPSIS
        Disconnects from the current Ceph Dashboard session.

    .DESCRIPTION
        Clears the stored Ceph session token and connection information.
        After disconnecting, you must call Connect-Ceph again to interact
        with the Ceph cluster.

    .EXAMPLE
        Disconnect-Ceph
        Disconnects from the current Ceph Dashboard session.

    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param()

    if (-not $script:CephSession) {
        Write-Warning 'No active Ceph connection to disconnect.'
        return
    }

    $server = $script:CephSession.Server
    $username = $script:CephSession.Username

    # Attempt to logout via API (invalidate token server-side)
    try {
        $logoutParams = @{
            Uri         = "$($script:CephSession.BaseUri)/api/auth/logout"
            Method      = 'POST'
            Headers     = @{ Authorization = "Bearer $($script:CephSession.Token)" }
            ContentType = 'application/json'
        }
        if ($script:CephSession.SkipCertificateCheck) {
            $logoutParams['SkipCertificateCheck'] = $true
        }
        Invoke-RestMethod @logoutParams -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        Write-Verbose "Logout API call failed: $_"
    }

    $script:CephSession = $null

    Write-Verbose "Disconnected from Ceph Dashboard at $server as $username"
}
