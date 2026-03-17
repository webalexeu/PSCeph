function Get-CephHealth {
    <#
    .SYNOPSIS
        Gets the health status of the Ceph cluster

    .DESCRIPTION
        Retrieves the current health status of the Ceph cluster including
        overall status, checks, and any health warnings or errors.

    .PARAMETER Full
        Returns detailed health information including all checks and mutes.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephHealth
        Returns the basic health status of the cluster.

    .EXAMPLE
        Get-CephHealth -Full
        Returns detailed health information including all checks.

    .OUTPUTS
        PSCustomObject representing the cluster health status.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$Full,

        [Parameter()]
        [switch]$Raw
    )

    $endpoint = if ($Full) { '/api/health/full' } else { '/api/health/minimal' }
    $response = Invoke-CephApi -Endpoint $endpoint

    if ($Raw) {
        return $response
    }

    if ($Full) {
        [PSCustomObject]@{
            PSTypeName   = 'PSCeph.HealthFull'
            Status       = $response.health.status
            Checks       = $response.health.checks
            Mutes        = $response.health.mutes
            MonStatus    = $response.mon_status
            OSDMap       = $response.osd_map
            MgrMap       = $response.mgr_map
            FSMap        = $response.fs_map
            Hosts        = $response.hosts
            Pools        = $response.pools
            IscsiDaemons = $response.iscsi_daemons
            RgwDaemons   = $response.rgw_daemons
            Df           = $response.df
            ClientPerf   = $response.client_perf
            Scrub        = $response.scrub_status
            PgInfo       = $response.pg_info
        }
    }
    else {
        [PSCustomObject]@{
            PSTypeName = 'PSCeph.Health'
            Status     = $response.health.status
            Checks     = $response.health.checks
        }
    }
}
