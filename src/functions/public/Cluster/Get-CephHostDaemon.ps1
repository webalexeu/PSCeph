function Get-CephHostDaemon {
    <#
    .SYNOPSIS
        Gets daemons running on a Ceph cluster host.

    .DESCRIPTION
        Retrieves information about Ceph daemons running on a specific host,
        including daemon type, ID, status, and version.

    .PARAMETER Hostname
        The hostname to get daemons for.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephHostDaemon -Hostname 'ceph-node1'
        Returns all daemons on the specified host.

    .EXAMPLE
        Get-CephHost | Get-CephHostDaemon
        Returns daemons for all hosts in the cluster.

    .EXAMPLE
        Get-CephHostDaemon -Hostname 'ceph-node1' | Where-Object { $_.DaemonType -eq 'osd' }
        Returns only OSD daemons on the host.

    .OUTPUTS
        PSCustomObject[] representing host daemons.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint "/api/host/$Hostname/daemons"

        if ($Raw) {
            return $response
        }

        foreach ($daemon in $response) {
            [PSCustomObject]@{
                PSTypeName     = 'PSCeph.HostDaemon'
                Hostname       = $Hostname
                DaemonType     = $daemon.daemon_type
                DaemonId       = $daemon.daemon_id
                DaemonName     = $daemon.daemon_name
                Status         = $daemon.status
                StatusDesc     = $daemon.status_desc
                Version        = $daemon.version
                Container      = $daemon.container_id
                ContainerImage = $daemon.container_image_name
                Started        = $daemon.started
                LastRefresh    = $daemon.last_refresh
            }
        }
    }
}
