function Get-CephFS {
    <#
    .SYNOPSIS
        Gets CephFS filesystem information

    .DESCRIPTION
        Retrieves information about CephFS filesystems in the cluster,
        including MDS daemons, pools, and mount information.

    .PARAMETER Name
        The name of a specific filesystem to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephFS
        Returns all CephFS filesystems.

    .EXAMPLE
        Get-CephFS -Name 'cephfs'
        Returns a specific filesystem.

    .EXAMPLE
        Get-CephFS | Select-Object Name, DataPools, MetadataPool
        Returns filesystem pool information.

    .OUTPUTS
        PSCustomObject[] representing CephFS filesystems.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Filesystem', 'FsName')]
        [string]$Name,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($Name) {
            $response = Invoke-CephApi -Endpoint "/api/cephfs/$Name"
            if ($Raw) {
                return $response
            }
            [PSCustomObject]@{
                PSTypeName     = 'PSCeph.CephFS'
                Name           = $response.cephfs.name
                Id             = $response.cephfs.id
                MetadataPool   = $response.cephfs.metadata_pool
                MetadataPoolId = $response.cephfs.metadata_pool_id
                DataPools      = $response.cephfs.data_pools
                DataPoolIds    = $response.cephfs.data_pool_ids
                MdsMap         = $response.cephfs.mdsmap
                Standbys       = $response.standbys
                ClientCount    = $response.clients.count
                Clients        = $response.clients.data
                MdsCounters    = $response.mds_counters
            }
        }
        else {
            $response = Invoke-CephApi -Endpoint '/api/cephfs'
            if ($Raw) {
                return $response
            }
            foreach ($fs in $response) {
                [PSCustomObject]@{
                    PSTypeName         = 'PSCeph.CephFS'
                    Name               = $fs.mdsmap.fs_name
                    Id                 = $fs.id
                    MetadataPool       = $fs.mdsmap.metadata_pool
                    DataPools          = $fs.mdsmap.data_pools
                    MaxMds             = $fs.mdsmap.max_mds
                    InMds              = $fs.mdsmap.in
                    UpMds              = $fs.mdsmap.up
                    StandbyCountWanted = $fs.mdsmap.standby_count_wanted
                }
            }
        }
    }
}
