function Get-CephRBDSnapshot {
    <#
    .SYNOPSIS
        Gets RBD image snapshots.

    .DESCRIPTION
        Retrieves snapshot information for a specific RBD image,
        including snapshot name, size, and protection status.

    .PARAMETER PoolName
        The name of the pool containing the image.

    .PARAMETER ImageName
        The name of the RBD image.

    .PARAMETER Namespace
        The RBD namespace within the pool.

    .PARAMETER SnapshotName
        Optional name of a specific snapshot to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephRBDSnapshot -PoolName 'rbd' -ImageName 'myimage'
        Returns all snapshots for the specified image.

    .EXAMPLE
        Get-CephRBDImage -PoolName 'rbd' | Get-CephRBDSnapshot
        Returns snapshots for all images in the pool.

    .EXAMPLE
        Get-CephRBDSnapshot -PoolName 'rbd' -ImageName 'myimage' -SnapshotName 'snap1'
        Returns a specific snapshot.

    .OUTPUTS
        PSCustomObject[] representing snapshots.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Pool')]
        [string]$PoolName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Image')]
        [string]$ImageName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Namespace,

        [Parameter()]
        [Alias('Snapshot')]
        [string]$SnapshotName,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $image = Get-CephRBDImage -PoolName $PoolName -ImageName $ImageName -Namespace $Namespace

        if (-not $image.Snapshots) {
            return
        }

        if ($Raw) {
            if ($SnapshotName) {
                return $image.Snapshots | Where-Object { $_.name -eq $SnapshotName }
            }
            return $image.Snapshots
        }

        $snapshots = foreach ($snap in $image.Snapshots) {
            [PSCustomObject]@{
                PSTypeName  = 'PSCeph.RBDSnapshot'
                Name        = $snap.name
                Id          = $snap.id
                PoolName    = $PoolName
                ImageName   = $ImageName
                Namespace   = $Namespace
                Size        = $snap.size
                SizeHuman   = "{0:N2} GB" -f ($snap.size / 1GB)
                IsProtected = $snap.is_protected
                Timestamp   = $snap.timestamp
                Children    = $snap.children
            }
        }

        if ($SnapshotName) {
            $snapshots | Where-Object { $_.Name -eq $SnapshotName }
        }
        else {
            $snapshots
        }
    }
}
