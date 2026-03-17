function New-CephPool {
    <#
    .SYNOPSIS
        Creates a new Ceph storage pool.

    .DESCRIPTION
        Creates a new replicated or erasure-coded pool in the Ceph cluster
        with specified parameters.

    .PARAMETER Name
        The name for the new pool.

    .PARAMETER PoolType
        The type of pool: 'replicated' or 'erasure'.

    .PARAMETER Size
        The replication size (number of copies). Only for replicated pools.

    .PARAMETER MinSize
        The minimum number of replicas required for I/O. Only for replicated pools.

    .PARAMETER PgNum
        The number of placement groups. If not specified, uses autoscaling.

    .PARAMETER PgAutoscaleMode
        The PG autoscale mode: 'on', 'off', or 'warn'. Defaults to 'on'.

    .PARAMETER CrushRule
        The CRUSH rule name to use for data placement.

    .PARAMETER Application
        The application type: 'rbd', 'cephfs', 'rgw', etc.

    .PARAMETER ErasureCodeProfile
        The erasure code profile name. Required for erasure-coded pools.

    .PARAMETER Compression
        Enable compression mode: 'none', 'passive', 'aggressive', or 'force'.

    .EXAMPLE
        New-CephPool -Name 'mypool' -Size 3
        Creates a new replicated pool with 3 replicas.

    .EXAMPLE
        New-CephPool -Name 'ec-pool' -PoolType erasure -ErasureCodeProfile 'default'
        Creates a new erasure-coded pool.

    .EXAMPLE
        New-CephPool -Name 'compressed-pool' -Size 3 -Compression aggressive -Application rbd
        Creates a replicated pool with aggressive compression for RBD.

    .OUTPUTS
        PSCustomObject representing the created pool.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('replicated', 'erasure')]
        [string]$PoolType = 'replicated',

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$Size = 3,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MinSize,

        [Parameter()]
        [ValidateRange(1, 32768)]
        [int]$PgNum,

        [Parameter()]
        [ValidateSet('on', 'off', 'warn')]
        [string]$PgAutoscaleMode = 'on',

        [Parameter()]
        [string]$CrushRule,

        [Parameter()]
        [ValidateSet('rbd', 'cephfs', 'rgw', 'nfs', 'smb')]
        [string]$Application,

        [Parameter()]
        [string]$ErasureCodeProfile,

        [Parameter()]
        [ValidateSet('none', 'passive', 'aggressive', 'force')]
        [string]$Compression
    )

    if ($PoolType -eq 'erasure' -and -not $ErasureCodeProfile) {
        throw 'ErasureCodeProfile is required when creating an erasure-coded pool.'
    }

    $body = @{
        pool      = $Name
        pool_type = $PoolType
        pg_autoscale_mode = $PgAutoscaleMode
    }

    if ($PoolType -eq 'replicated') {
        $body['size'] = $Size
        if ($MinSize) { $body['min_size'] = $MinSize }
    }
    else {
        $body['erasure_code_profile'] = $ErasureCodeProfile
    }

    if ($PgNum) { $body['pg_num'] = $PgNum }
    if ($CrushRule) { $body['rule_name'] = $CrushRule }
    if ($Application) { $body['application'] = @{ $Application = @{} } }
    if ($Compression) { $body['compression_mode'] = $Compression }

    if ($PSCmdlet.ShouldProcess($Name, 'Create Ceph pool')) {
        Invoke-CephApi -Endpoint '/api/pool' -Method POST -Body $body

        Get-CephPool -Name $Name
    }
}
