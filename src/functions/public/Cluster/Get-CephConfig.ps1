function Get-CephConfig {
    <#
    .SYNOPSIS
        Gets the Ceph cluster configuration.

    .DESCRIPTION
        Retrieves configuration options from the Ceph cluster. Can filter
        by configuration name pattern.

    .PARAMETER Name
        Optional filter for configuration option name. Supports wildcards.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephConfig
        Returns all configuration options.

    .EXAMPLE
        Get-CephConfig -Name 'mon*'
        Returns configuration options starting with 'mon'.

    .EXAMPLE
        Get-CephConfig -Name 'osd_pool_default_size'
        Returns a specific configuration option.

    .OUTPUTS
        PSCustomObject[] representing configuration options.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [switch]$Raw
    )

    $response = Invoke-CephApi -Endpoint '/api/cluster_conf'

    if ($Raw) {
        if ($Name) {
            return $response | Where-Object { $_.name -like $Name }
        }
        return $response
    }

    $configs = foreach ($config in $response) {
        [PSCustomObject]@{
            PSTypeName  = 'PSCeph.Config'
            Name        = $config.name
            Value       = $config.value
            Source      = $config.source
            Section     = $config.section
            Description = $config.desc
            LongDesc    = $config.long_desc
            Default     = $config.default
            Type        = $config.type
            Min         = $config.min
            Max         = $config.max
            CanUpdate   = $config.can_update_at_runtime
        }
    }

    if ($Name) {
        $configs | Where-Object { $_.Name -like $Name }
    }
    else {
        $configs
    }
}
