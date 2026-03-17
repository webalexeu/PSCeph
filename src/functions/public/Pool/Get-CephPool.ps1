function Get-CephPool {
    <#
    .SYNOPSIS
        Gets Ceph storage pools

    .DESCRIPTION
        Retrieves information about all pools or a specific pool in the
        Ceph cluster, including size, PG count, and usage statistics.

    .PARAMETER Name
        The name of a specific pool to retrieve. If not specified, returns all pools.

    .PARAMETER Stats
        Include detailed statistics for each pool.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephPool
        Returns all pools in the cluster.

    .EXAMPLE
        Get-CephPool -Name 'rbd'
        Returns information for the 'rbd' pool.

    .EXAMPLE
        Get-CephPool -Stats | Select-Object Name, Size, PgNum, BytesUsed
        Returns all pools with usage statistics.

    .OUTPUTS
        PSCustomObject[] representing storage pools.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PoolName')]
        [string]$Name,

        [Parameter()]
        [switch]$Stats,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $endpoint = '/api/pool'
        if ($Stats) {
            $endpoint += '?stats=true'
        }

        $response = Invoke-CephApi -Endpoint $endpoint

        if ($Raw) {
            if ($Name) {
                return $response | Where-Object { $_.pool_name -eq $Name }
            }
            return $response
        }

        $pools = foreach ($pool in $response) {
            [PSCustomObject]@{
                PSTypeName         = 'PSCeph.Pool'
                Name               = $pool.pool_name
                PoolId             = $pool.pool
                Type               = $pool.type
                Size               = $pool.size
                MinSize            = $pool.min_size
                PgNum              = $pool.pg_num
                PgPlacementNum     = $pool.pg_placement_num
                PgAutoscaleMode    = $pool.pg_autoscale_mode
                CrushRule          = $pool.crush_rule
                Application        = $pool.application_metadata
                BytesUsed          = $pool.stats.bytes_used
                MaxAvail           = $pool.stats.max_avail
                Objects            = $pool.stats.objects
                ReadOps            = $pool.stats.rd
                WriteOps           = $pool.stats.wr
                ReadBytes          = $pool.stats.rd_bytes
                WriteBytes         = $pool.stats.wr_bytes
                Quota              = $pool.quota_max_bytes
                QuotaObjects       = $pool.quota_max_objects
                CompressionMode    = $pool.options.compression_mode
                ErasureCodeProfile = $pool.erasure_code_profile
            }
        }

        if ($Name) {
            $pools | Where-Object { $_.Name -eq $Name }
        }
        else {
            $pools
        }
    }
}
