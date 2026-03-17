function Get-CephOSD {
    <#
    .SYNOPSIS
        Gets Ceph OSD (Object Storage Daemon) information.

    .DESCRIPTION
        Retrieves information about all OSDs or a specific OSD in the
        Ceph cluster, including status, host, device info, and statistics.

    .PARAMETER OsdId
        The numeric ID of a specific OSD to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephOSD
        Returns all OSDs in the cluster.

    .EXAMPLE
        Get-CephOSD -OsdId 0
        Returns information for OSD.0.

    .EXAMPLE
        Get-CephOSD | Where-Object { $_.Status -eq 'up' -and $_.In }
        Returns all OSDs that are up and in.

    .OUTPUTS
        PSCustomObject[] representing OSDs.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [int]$OsdId,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($PSBoundParameters.ContainsKey('OsdId')) {
            $response = Invoke-CephApi -Endpoint "/api/osd/$OsdId"
            if ($Raw) {
                return $response
            }
            [PSCustomObject]@{
                PSTypeName     = 'PSCeph.OSD'
                OsdId          = $response.osd
                Name           = "osd.$($response.osd)"
                Uuid           = $response.uuid
                Status         = if ($response.up) { 'up' } else { 'down' }
                Up             = $response.up -eq 1
                In             = $response.in -eq 1
                State          = $response.state
                Hostname       = $response.host
                PublicAddr     = $response.public_addr
                ClusterAddr    = $response.cluster_addr
                DeviceClass    = $response.device_class
                PGs            = $response.num_pgs
                OsdObjectStore = $response.osd_objectstore
                CrushWeight    = $response.crush_weight
                ReWeight       = $response.reweight
                KbUsed         = $response.kb_used
                KbAvail        = $response.kb_avail
            }
        }
        else {
            $response = Invoke-CephApi -Endpoint '/api/osd'
            if ($Raw) {
                return $response
            }
            foreach ($osd in $response) {
                [PSCustomObject]@{
                    PSTypeName  = 'PSCeph.OSD'
                    OsdId       = $osd.osd
                    Name        = "osd.$($osd.osd)"
                    Uuid        = $osd.uuid
                    Status      = if ($osd.up) { 'up' } else { 'down' }
                    Up          = $osd.up -eq 1
                    In          = $osd.in -eq 1
                    State       = $osd.state
                    Hostname    = $osd.host
                    DeviceClass = $osd.device_class
                    PGs         = $osd.num_pgs
                    CrushWeight = $osd.crush_weight
                    ReWeight    = $osd.reweight
                }
            }
        }
    }
}
