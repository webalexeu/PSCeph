function Get-CephStatus {
    <#
    .SYNOPSIS
        Gets the overall status of the Ceph cluster

    .DESCRIPTION
        Retrieves comprehensive cluster status including FSID, health,
        mon/osd/mds/mgr maps, and performance metrics.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephStatus
        Returns the overall cluster status.

    .EXAMPLE
        Get-CephStatus | Select-Object FSID, Health, OSDMap
        Returns specific status fields.

    .OUTPUTS
        PSCustomObject representing the overall cluster status.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Raw
    )

    $response = Invoke-CephApi -Endpoint '/api/health/full'

    if ($Raw) {
        return $response
    }

    # Extract FSID from mon_status.monmap.fsid
    $fsid = $response.mon_status.monmap.fsid

    # Extract health status
    $healthStatus = $response.health.status

    [PSCustomObject]@{
        PSTypeName   = 'PSCeph.ClusterStatus'
        FSID         = $fsid
        Health       = $healthStatus
        MonitorCount = $response.mon_status.monmap.mons.Count
        OSDCount     = $response.osd_map.osds.Count
        OSDs_Up      = ($response.osd_map.osds | Where-Object { $_.up -eq 1 }).Count
        OSDs_In      = ($response.osd_map.osds | Where-Object { $_.in -eq 1 }).Count
        PoolCount    = $response.pools.Count
        PGs_Total    = $response.pg_info.statuses.PSObject.Properties.Value | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        MgrActive    = $response.mgr_map.active_name
    }
}
