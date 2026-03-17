function New-CephSMBShare {
    <#
    .SYNOPSIS
        Creates a new Ceph SMB share

    .DESCRIPTION
        Creates a new SMB share in a Ceph SMB cluster pointing to
        a CephFS path.

    .PARAMETER ClusterId
        The ID of the SMB cluster to create the share in.

    .PARAMETER ShareName
        The name of the share (visible to clients).

    .PARAMETER Filesystem
        The CephFS filesystem name.

    .PARAMETER Path
        The path within CephFS to share.

    .PARAMETER Subvolume
        Optional CephFS subvolume name.

    .PARAMETER SubvolumeGroup
        Optional CephFS subvolume group name.

    .PARAMETER ReadOnly
        Make the share read-only.

    .PARAMETER Hidden
        Hide the share from network browse lists. By default, shares are browsable.

    .EXAMPLE
        New-CephSMBShare -ClusterId 'smb1' -ShareName 'data' -Filesystem 'cephfs' -Path '/data'
        Creates a new SMB share.

    .EXAMPLE
        New-CephSMBShare -ClusterId 'smb1' -ShareName 'readonly' -Filesystem 'cephfs' -Path '/backup' -ReadOnly
        Creates a read-only SMB share.

    .OUTPUTS
        PSCustomObject representing the created share.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter(Mandatory)]
        [Alias('Name')]
        [string]$ShareName,

        [Parameter(Mandatory)]
        [string]$Filesystem,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$Subvolume,

        [Parameter()]
        [string]$SubvolumeGroup,

        [Parameter()]
        [switch]$ReadOnly,

        [Parameter()]
        [switch]$Hidden
    )

    $body = @{
        cluster_id = $ClusterId
        share_id   = $ShareName
        name       = $ShareName
        cephfs     = @{
            volume = $Filesystem
            path   = $Path
        }
        readonly   = $ReadOnly.IsPresent
        browsable  = -not $Hidden.IsPresent
    }

    if ($Subvolume) {
        $body['cephfs']['subvolume'] = $Subvolume
    }
    if ($SubvolumeGroup) {
        $body['cephfs']['subvolumegroup'] = $SubvolumeGroup
    }

    if ($PSCmdlet.ShouldProcess("$ClusterId/$ShareName", 'Create SMB share')) {
        Invoke-CephApi -Endpoint '/api/smb/share' -Method POST -Body $body

        Get-CephSMBShare -ClusterId $ClusterId -ShareName $ShareName
    }
}
