function Get-CephRBDImage {
    <#
    .SYNOPSIS
        Gets RBD (RADOS Block Device) images.

    .DESCRIPTION
        Retrieves information about RBD images in a pool, including
        size, features, and snapshot information.

    .PARAMETER PoolName
        The name of the pool containing the images. If not specified,
        searches all pools with RBD application.

    .PARAMETER ImageName
        The name of a specific image to retrieve.

    .PARAMETER Namespace
        The RBD namespace within the pool.

    .PARAMETER Limit
        Maximum number of images to return. Defaults to 100.

    .PARAMETER Offset
        Number of images to skip for pagination. Defaults to 0.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephRBDImage -PoolName 'rbd'
        Returns all RBD images in the 'rbd' pool.

    .EXAMPLE
        Get-CephRBDImage -PoolName 'rbd' -ImageName 'myimage'
        Returns a specific RBD image.

    .EXAMPLE
        Get-CephRBDImage | Select-Object Name, Size, PoolName
        Returns all RBD images with basic info.

    .OUTPUTS
        PSCustomObject[] representing RBD images.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Name', 'Image')]
        [string]$ImageName,

        [Parameter()]
        [string]$Namespace,

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$Limit = 100,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Offset = 0,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($ImageName -and $PoolName) {
            $endpoint = "/api/block/image/$PoolName"
            if ($Namespace) {
                $endpoint += "/$Namespace"
            }
            else {
                $endpoint += '/'
            }
            $endpoint += "/$ImageName"

            $response = Invoke-CephApi -Endpoint $endpoint

            if ($Raw) {
                return $response
            }

            [PSCustomObject]@{
                PSTypeName      = 'PSCeph.RBDImage'
                Name            = $response.name
                PoolName        = $response.pool_name
                Namespace       = $response.namespace
                Id              = $response.id
                Size            = $response.size
                SizeHuman       = $response.disk_usage | ForEach-Object { "{0:N2} GB" -f ($_ / 1GB) }
                ObjectSize      = $response.obj_size
                NumObjects      = $response.num_objs
                Features        = $response.features_name
                FeaturesEnabled = $response.features
                Order           = $response.order
                BlockNamePrefix = $response.block_name_prefix
                Parent          = $response.parent
                Snapshots       = $response.snapshots
                SnapshotCount   = ($response.snapshots | Measure-Object).Count
                Timestamp       = $response.timestamp
                StripeUnit      = $response.stripe_unit
                StripeCount     = $response.stripe_count
                DataPool        = $response.data_pool
                Configuration   = $response.configuration
            }
        }
        else {
            $queryParams = @()
            if ($PoolName) { $queryParams += "pool_name=$PoolName" }
            $queryParams += "limit=$Limit"
            $queryParams += "offset=$Offset"

            $endpoint = '/api/block/image?' + ($queryParams -join '&')

            $response = Invoke-CephApi -Endpoint $endpoint

            if ($Raw) {
                return $response
            }

            # Handle wrapped response (v2 API returns {value: [...], pool_name: ...})
            $images = if ($response.value) { $response.value } else { $response }

            foreach ($image in $images) {
                $image.PSObject.TypeNames.Insert(0, 'PSCeph.RBDImage')
                $image
            }
        }
    }
}
