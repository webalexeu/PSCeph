function Get-CephConnection {
    <#
    .SYNOPSIS
        Gets information about the current Ceph Dashboard connection

    .DESCRIPTION
        Returns details about the current Ceph Dashboard session including
        the server, port, username, and connection time.

    .EXAMPLE
        Get-CephConnection
        Returns the current connection information.

    .EXAMPLE
        if (Get-CephConnection) { Get-CephHealth }
        Checks if connected before running commands.

    .OUTPUTS
        PSCustomObject representing the connection information, or $null if not connected.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    if (-not $script:CephSession) {
        return $null
    }

    [PSCustomObject]@{
        PSTypeName  = 'PSCeph.ConnectionInfo'
        Server      = $script:CephSession.Server
        Port        = $script:CephSession.Port
        Username    = $script:CephSession.Username
        ConnectedAt = $script:CephSession.ConnectedAt
        TokenExpiry = $script:CephSession.TokenExpiry
        Permissions = $script:CephSession.Permissions
    }
}
