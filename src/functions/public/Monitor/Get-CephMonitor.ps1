function Get-CephMonitor {
    <#
    .SYNOPSIS
        Gets Ceph Monitor daemon information.

    .DESCRIPTION
        Retrieves information about all monitors or a specific monitor
        in the Ceph cluster, including status, address, and quorum state.

    .PARAMETER Name
        The name of a specific monitor to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephMonitor
        Returns all monitors in the cluster.

    .EXAMPLE
        Get-CephMonitor -Name 'mon.a'
        Returns information for a specific monitor.

    .EXAMPLE
        Get-CephMonitor | Where-Object { $_.InQuorum }
        Returns all monitors that are in quorum.

    .OUTPUTS
        PSCustomObject[] representing monitors.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint '/api/monitor'

        if ($Raw) {
            return $response
        }

        $monitors = foreach ($mon in $response.mon_status.monmap.mons) {
            $inQuorum = $response.mon_status.quorum_names -contains $mon.name

            [PSCustomObject]@{
                PSTypeName    = 'PSCeph.Monitor'
                Name          = $mon.name
                Rank          = $mon.rank
                Address       = $mon.addr
                PublicAddr    = $mon.public_addr
                PublicAddrs   = $mon.public_addrs
                InQuorum      = $inQuorum
                Priority      = $mon.priority
                Weight        = $mon.weight
                CrushLocation = $mon.crush_location
            }
        }

        if ($Name) {
            $monitors | Where-Object { $_.Name -eq $Name -or $_.Name -eq "mon.$Name" }
        }
        else {
            $monitors
        }
    }
}
