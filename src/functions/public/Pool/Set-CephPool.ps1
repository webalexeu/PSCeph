function Set-CephPool {
    <#
    .SYNOPSIS
        Modifies a Ceph storage pool

    .DESCRIPTION
        Updates properties of an existing Ceph pool such as size,
        PG autoscale mode, compression settings, or quotas.

    .PARAMETER Name
        The name of the pool to modify.

    .PARAMETER Size
        The replication size (number of copies). Only for replicated pools.

    .PARAMETER MinSize
        The minimum number of replicas required for I/O.

    .PARAMETER PgNum
        The number of placement groups.

    .PARAMETER PgAutoscaleMode
        The PG autoscale mode: 'on', 'off', or 'warn'.

    .PARAMETER Compression
        Set compression mode: 'none', 'passive', 'aggressive', or 'force'.

    .PARAMETER QuotaMaxBytes
        Maximum bytes quota for the pool. Set to 0 to remove quota.

    .PARAMETER QuotaMaxObjects
        Maximum objects quota for the pool. Set to 0 to remove quota.

    .EXAMPLE
        Set-CephPool -Name 'mypool' -Size 2
        Changes the replication size to 2.

    .EXAMPLE
        Set-CephPool -Name 'mypool' -Compression aggressive
        Enables aggressive compression on the pool.

    .EXAMPLE
        Set-CephPool -Name 'mypool' -QuotaMaxBytes 1TB
        Sets a 1TB quota on the pool.

    .OUTPUTS
        PSCustomObject representing the modified pool.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('PoolName')]
        [string]$Name,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$Size,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MinSize,

        [Parameter()]
        [ValidateRange(1, 32768)]
        [int]$PgNum,

        [Parameter()]
        [ValidateSet('on', 'off', 'warn')]
        [string]$PgAutoscaleMode,

        [Parameter()]
        [ValidateSet('none', 'passive', 'aggressive', 'force')]
        [string]$Compression,

        [Parameter()]
        [long]$QuotaMaxBytes,

        [Parameter()]
        [long]$QuotaMaxObjects
    )

    process {
        $body = @{}

        if ($PSBoundParameters.ContainsKey('Size')) {
            $body['size'] = $Size
        }
        if ($PSBoundParameters.ContainsKey('MinSize')) {
            $body['min_size'] = $MinSize
        }
        if ($PSBoundParameters.ContainsKey('PgNum')) {
            $body['pg_num'] = $PgNum
        }
        if ($PSBoundParameters.ContainsKey('PgAutoscaleMode')) {
            $body['pg_autoscale_mode'] = $PgAutoscaleMode
        }
        if ($PSBoundParameters.ContainsKey('Compression')) {
            $body['compression_mode'] = $Compression
        }
        if ($PSBoundParameters.ContainsKey('QuotaMaxBytes')) {
            $body['quota_max_bytes'] = $QuotaMaxBytes
        }
        if ($PSBoundParameters.ContainsKey('QuotaMaxObjects')) {
            $body['quota_max_objects'] = $QuotaMaxObjects
        }

        if ($body.Count -eq 0) {
            Write-Warning 'No modifications specified.'
            return
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Modify Ceph pool')) {
            Invoke-CephApi -Endpoint "/api/pool/$Name" -Method PUT -Body $body

            Get-CephPool -Name $Name
        }
    }
}
