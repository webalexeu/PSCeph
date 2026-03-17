function Get-CephStatus {
    <#
    .SYNOPSIS
        Gets the overall status of the Ceph cluster.

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

    $response = Invoke-CephApi -Endpoint '/api/cluster'

    if ($Raw) {
        return $response
    }

    [PSCustomObject]@{
        PSTypeName = 'PSCeph.ClusterStatus'
        FSID       = $response.fsid
        Status     = $response.status
    }
}
