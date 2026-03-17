function New-CephNVMeoFNamespace {
    <#
    .SYNOPSIS
        Creates a new NVMe-oF namespace.

    .DESCRIPTION
        Creates a new namespace in an NVMe-oF subsystem backed by
        an RBD image.

    .PARAMETER Nqn
        The NQN of the subsystem to add the namespace to.

    .PARAMETER PoolName
        The name of the RBD pool containing the image.

    .PARAMETER ImageName
        The name of the RBD image to use.

    .PARAMETER RbdNamespace
        Optional RBD namespace within the pool.

    .PARAMETER BlockSize
        Block size in bytes. Defaults to 512.

    .PARAMETER CreateImage
        Create the RBD image if it doesn't exist.

    .PARAMETER Size
        Size of the RBD image to create (required if CreateImage is specified).

    .EXAMPLE
        New-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1' -PoolName 'rbd' -ImageName 'volume1'
        Creates a namespace backed by an existing RBD image.

    .EXAMPLE
        New-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1' -PoolName 'rbd' -ImageName 'volume1' -CreateImage -Size 100GB
        Creates a namespace and a new 100GB RBD image.

    .OUTPUTS
        PSCustomObject representing the created namespace.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter(Mandatory)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(Mandatory)]
        [Alias('Image')]
        [string]$ImageName,

        [Parameter()]
        [string]$RbdNamespace,

        [Parameter()]
        [ValidateSet(512, 4096)]
        [int]$BlockSize = 512,

        [Parameter()]
        [switch]$CreateImage,

        [Parameter()]
        [long]$Size
    )

    if ($CreateImage -and -not $Size) {
        throw 'Size is required when CreateImage is specified.'
    }

    $body = @{
        rbd_pool_name  = $PoolName
        rbd_image_name = $ImageName
        block_size     = $BlockSize
    }

    if ($RbdNamespace) { $body['rbd_namespace'] = $RbdNamespace }
    if ($CreateImage) {
        $body['create_image'] = $true
        $body['size'] = $Size
    }

    if ($PSCmdlet.ShouldProcess("$Nqn/$PoolName/$ImageName", 'Create NVMe-oF namespace')) {
        $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
        $null = Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/namespace" -Method POST -Body $body

        Get-CephNVMeoFNamespace -Nqn $Nqn | Select-Object -Last 1
    }
}
