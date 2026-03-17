function Get-CephFSDirectory {
    <#
    .SYNOPSIS
        Gets directories in a CephFS filesystem.

    .DESCRIPTION
        Retrieves directory information from a CephFS filesystem,
        including quotas, layout, and subdirectories.

    .PARAMETER Filesystem
        The name of the CephFS filesystem.

    .PARAMETER Path
        The path within the filesystem. Defaults to root '/'.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephFSDirectory -Filesystem 'cephfs'
        Returns the root directory of the filesystem.

    .EXAMPLE
        Get-CephFSDirectory -Filesystem 'cephfs' -Path '/data'
        Returns the '/data' directory.

    .EXAMPLE
        Get-CephFS | Get-CephFSDirectory
        Returns root directories for all filesystems.

    .OUTPUTS
        PSCustomObject[] representing directories.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name', 'FsName')]
        [string]$Filesystem,

        [Parameter()]
        [string]$Path = '/',

        [Parameter()]
        [switch]$Raw
    )

    process {
        $encodedPath = [System.Web.HttpUtility]::UrlEncode($Path)
        $endpoint = "/api/cephfs/$Filesystem/ls_dir?path=$encodedPath"

        $response = Invoke-CephApi -Endpoint $endpoint

        if ($Raw) {
            return $response
        }

        foreach ($dir in $response) {
            [PSCustomObject]@{
                PSTypeName  = 'PSCeph.CephFSDirectory'
                Filesystem  = $Filesystem
                Name        = $dir.name
                Path        = $dir.path
                ParentPath  = $Path
                IsDirectory = $dir.is_dir
                Uid         = $dir.uid
                Gid         = $dir.gid
                Mode        = $dir.mode
                ModeString  = $dir.mode_string
                Size        = $dir.size
                Mtime       = $dir.mtime
                Ctime       = $dir.ctime
                Quotas      = $dir.quotas
            }
        }
    }
}
