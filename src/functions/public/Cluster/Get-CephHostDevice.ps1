function Get-CephHostDevice {
    <#
    .SYNOPSIS
        Gets devices on a Ceph cluster host.

    .DESCRIPTION
        Retrieves information about storage devices on a specific host,
        including device path, type, size, and whether it's available for use.

    .PARAMETER Hostname
        The hostname to get devices for.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephHostDevice -Hostname 'ceph-node1'
        Returns all devices on the specified host.

    .EXAMPLE
        Get-CephHost | Get-CephHostDevice
        Returns devices for all hosts in the cluster.

    .EXAMPLE
        Get-CephHostDevice -Hostname 'ceph-node1' | Where-Object { $_.Available }
        Returns only available devices on the host.

    .OUTPUTS
        PSCustomObject[] representing host devices.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint "/api/host/$Hostname/devices"

        if ($Raw) {
            return $response
        }

        foreach ($device in $response) {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.HostDevice'
                Hostname   = $Hostname
                Path       = $device.path
                DeviceId   = $device.device_id
                Type       = $device.human_readable_type
                Size       = $device.sys_api.size
                SizeHuman  = $device.human_readable_size
                Vendor     = $device.sys_api.vendor
                Model      = $device.sys_api.model
                Available  = $device.available
                Rejected   = $device.rejected_reasons
                OsdIds     = $device.osd_ids
            }
        }
    }
}
