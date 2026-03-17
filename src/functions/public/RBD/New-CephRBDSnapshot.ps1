function New-CephRBDSnapshot {
    <#
    .SYNOPSIS
        Creates a new RBD image snapshot

    .DESCRIPTION
        Creates a point-in-time snapshot of an RBD image.

    .PARAMETER PoolName
        The name of the pool containing the image.

    .PARAMETER ImageName
        The name of the RBD image to snapshot.

    .PARAMETER SnapshotName
        The name for the new snapshot.

    .PARAMETER Namespace
        The RBD namespace within the pool.

    .PARAMETER MirrorImageSnapshot
        Create a mirror image snapshot.

    .EXAMPLE
        New-CephRBDSnapshot -PoolName 'rbd' -ImageName 'myimage' -SnapshotName 'snap1'
        Creates a snapshot named 'snap1'.

    .EXAMPLE
        Get-CephRBDImage -PoolName 'rbd' | New-CephRBDSnapshot -SnapshotName ("backup-" + (Get-Date -Format 'yyyyMMdd'))
        Creates a dated backup snapshot for all images.

    .OUTPUTS
        PSCustomObject representing the created snapshot.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Image', 'Name')]
        [string]$ImageName,

        [Parameter(Mandatory)]
        [Alias('Snapshot')]
        [string]$SnapshotName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Namespace,

        [Parameter()]
        [switch]$MirrorImageSnapshot
    )

    process {
        $imagePath = if ($Namespace) { "$PoolName/$Namespace/$ImageName" } else { "$PoolName/$ImageName" }

        if ($PSCmdlet.ShouldProcess("$imagePath@$SnapshotName", 'Create RBD snapshot')) {
            $endpoint = "/api/block/image/$PoolName"
            if ($Namespace) {
                $endpoint += "/$Namespace"
            }
            else {
                $endpoint += '/'
            }
            $endpoint += "/$ImageName/snap"

            $body = @{
                snapshot_name = $SnapshotName
            }

            if ($MirrorImageSnapshot) {
                $body['mirrorImageSnapshot'] = $true
            }

            Invoke-CephApi -Endpoint $endpoint -Method POST -Body $body

            Get-CephRBDSnapshot -PoolName $PoolName -ImageName $ImageName -Namespace $Namespace -SnapshotName $SnapshotName
        }
    }
}
