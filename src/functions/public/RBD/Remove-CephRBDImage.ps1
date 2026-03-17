function Remove-CephRBDImage {
    <#
    .SYNOPSIS
        Removes an RBD image

    .DESCRIPTION
        Deletes an RBD image from the pool. The image must not have
        active snapshots unless using -Force.

    .PARAMETER PoolName
        The name of the pool containing the image.

    .PARAMETER ImageName
        The name of the image to remove.

    .PARAMETER Namespace
        The RBD namespace within the pool.

    .PARAMETER Force
        Force removal, bypassing safety checks.

    .EXAMPLE
        Remove-CephRBDImage -PoolName 'rbd' -ImageName 'myimage'
        Removes the specified RBD image.

    .EXAMPLE
        Get-CephRBDImage -PoolName 'rbd' | Where-Object Name -like 'temp-*' | Remove-CephRBDImage
        Removes all images matching the pattern.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'Image')]
        [string]$ImageName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Namespace,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        $imagePath = if ($Namespace) { "$PoolName/$Namespace/$ImageName" } else { "$PoolName/$ImageName" }

        if ($PSCmdlet.ShouldProcess($imagePath, 'Remove RBD image')) {
            $endpoint = "/api/block/image/$PoolName"
            if ($Namespace) {
                $endpoint += "/$Namespace"
            }
            else {
                $endpoint += '/'
            }
            $endpoint += "/$ImageName"

            Invoke-CephApi -Endpoint $endpoint -Method DELETE
            Write-Verbose "RBD image '$imagePath' has been removed."
        }
    }
}
