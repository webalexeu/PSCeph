function Get-CephSMBShare {
    <#
    .SYNOPSIS
        Gets Ceph SMB shares.

    .DESCRIPTION
        Retrieves information about SMB shares in a Ceph SMB cluster,
        including path, permissions, and configuration.

    .PARAMETER ClusterId
        The ID of the SMB cluster containing the shares.

    .PARAMETER ShareName
        The name of a specific share to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephSMBShare -ClusterId 'smb1'
        Returns all shares in the cluster.

    .EXAMPLE
        Get-CephSMBShare -ClusterId 'smb1' -ShareName 'data'
        Returns a specific share.

    .EXAMPLE
        Get-CephSMBCluster | Get-CephSMBShare
        Returns shares for all SMB clusters.

    .OUTPUTS
        PSCustomObject[] representing SMB shares.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter()]
        [Alias('Name')]
        [string]$ShareName,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint "/api/smb/share?cluster_id=$ClusterId"

        if ($Raw) {
            if ($ShareName) {
                return $response | Where-Object { $_.share_id -eq $ShareName -or $_.name -eq $ShareName }
            }
            return $response
        }

        $shares = foreach ($share in $response) {
            [PSCustomObject]@{
                PSTypeName     = 'PSCeph.SMBShare'
                ClusterId      = $ClusterId
                ShareName      = $share.share_id
                Name           = $share.name
                Filesystem     = $share.cephfs.volume
                Path           = $share.cephfs.path
                Subvolume      = $share.cephfs.subvolume
                SubvolumeGroup = $share.cephfs.subvolumegroup
                Provider       = $share.cephfs.provider
                ReadOnly       = $share.readonly
                Browsable      = $share.browseable
            }
        }

        if ($ShareName) {
            $shares | Where-Object { $_.ShareName -eq $ShareName -or $_.Name -eq $ShareName }
        }
        else {
            $shares
        }
    }
}
