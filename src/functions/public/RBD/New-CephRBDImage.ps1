function New-CephRBDImage {
    <#
    .SYNOPSIS
        Creates a new RBD image

    .DESCRIPTION
        Creates a new RADOS Block Device image in the specified pool
        with the given size and features.

    .PARAMETER PoolName
        The name of the pool to create the image in.

    .PARAMETER ImageName
        The name for the new RBD image.

    .PARAMETER Size
        The size of the image in bytes. Accepts KB, MB, GB, TB suffixes.

    .PARAMETER Namespace
        Optional RBD namespace within the pool.

    .PARAMETER ObjectSize
        Object size in bytes. Defaults to 4MB.

    .PARAMETER Features
        Array of features to enable (e.g., 'layering', 'exclusive-lock', 'object-map').

    .PARAMETER DataPool
        Optional data pool for erasure-coded images.

    .PARAMETER StripeUnit
        Stripe unit size in bytes.

    .PARAMETER StripeCount
        Number of objects to stripe across.

    .EXAMPLE
        New-CephRBDImage -PoolName 'rbd' -ImageName 'myimage' -Size 10GB
        Creates a 10GB RBD image.

    .EXAMPLE
        New-CephRBDImage -PoolName 'rbd' -ImageName 'myimage' -Size 100GB -Features @('layering', 'exclusive-lock')
        Creates a 100GB image with specific features.

    .OUTPUTS
        PSCustomObject representing the created image.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(Mandatory)]
        [Alias('Name', 'Image')]
        [string]$ImageName,

        [Parameter(Mandatory)]
        [long]$Size,

        [Parameter()]
        [string]$Namespace,

        [Parameter()]
        [ValidateSet(4KB, 8KB, 16KB, 32KB, 64KB, 128KB, 256KB, 512KB, 1MB, 2MB, 4MB, 8MB, 16MB, 32MB)]
        [long]$ObjectSize = 4MB,

        [Parameter()]
        [ValidateSet('layering', 'striping', 'exclusive-lock', 'object-map', 'fast-diff', 'deep-flatten', 'journaling')]
        [string[]]$Features,

        [Parameter()]
        [string]$DataPool,

        [Parameter()]
        [long]$StripeUnit,

        [Parameter()]
        [int]$StripeCount
    )

    $body = @{
        pool_name = $PoolName
        name      = $ImageName
        size      = $Size
        obj_size  = $ObjectSize
    }

    if ($Namespace) {
        $body['namespace'] = $Namespace
    }
    if ($Features) {
        $body['features'] = $Features
    }
    if ($DataPool) {
        $body['data_pool'] = $DataPool
    }
    if ($StripeUnit) {
        $body['stripe_unit'] = $StripeUnit
    }
    if ($StripeCount) {
        $body['stripe_count'] = $StripeCount
    }

    if ($PSCmdlet.ShouldProcess("$PoolName/$ImageName", 'Create RBD image')) {
        Invoke-CephApi -Endpoint '/api/block/image' -Method POST -Body $body

        Get-CephRBDImage -PoolName $PoolName -ImageName $ImageName -Namespace $Namespace
    }
}
