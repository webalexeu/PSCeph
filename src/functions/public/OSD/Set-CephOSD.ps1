function Set-CephOSD {
    <#
    .SYNOPSIS
        Modifies an OSD state

    .DESCRIPTION
        Changes the state of an OSD, such as marking it in/out or
        adjusting its reweight value.

    .PARAMETER OsdId
        The numeric ID of the OSD to modify.

    .PARAMETER In
        Mark the OSD as 'in' (participating in data distribution).

    .PARAMETER Out
        Mark the OSD as 'out' (not participating in data distribution).

    .PARAMETER Down
        Mark the OSD as 'down'.

    .PARAMETER ReWeight
        Set the OSD reweight value (0.0 to 1.0).

    .PARAMETER DeviceClass
        Set the OSD device class (e.g., 'hdd', 'ssd', 'nvme').

    .EXAMPLE
        Set-CephOSD -OsdId 0 -Out
        Marks OSD.0 as out for maintenance.

    .EXAMPLE
        Set-CephOSD -OsdId 0 -In
        Marks OSD.0 as in after maintenance.

    .EXAMPLE
        Set-CephOSD -OsdId 0 -ReWeight 0.5
        Sets OSD.0 reweight to 50%.

    .OUTPUTS
        PSCustomObject representing the modified OSD.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [int]$OsdId,

        [Parameter(ParameterSetName = 'In')]
        [switch]$In,

        [Parameter(ParameterSetName = 'Out')]
        [switch]$Out,

        [Parameter()]
        [switch]$Down,

        [Parameter()]
        [ValidateRange(0.0, 1.0)]
        [double]$ReWeight,

        [Parameter()]
        [ValidateSet('hdd', 'ssd', 'nvme')]
        [string]$DeviceClass
    )

    process {
        $actions = @()

        if ($In) {
            $actions += 'in'
        }
        if ($Out) {
            $actions += 'out'
        }
        if ($Down) {
            $actions += 'down'
        }

        foreach ($action in $actions) {
            if ($PSCmdlet.ShouldProcess("OSD.$OsdId", "Mark as $action")) {
                Invoke-CephApi -Endpoint "/api/osd/$OsdId/mark" -Method PUT -Body @{ action = $action }
                Write-Verbose "OSD.$OsdId marked as $action"
            }
        }

        if ($PSBoundParameters.ContainsKey('ReWeight')) {
            if ($PSCmdlet.ShouldProcess("OSD.$OsdId", "Set reweight to $ReWeight")) {
                Invoke-CephApi -Endpoint "/api/osd/$OsdId/reweight" -Method POST -Body @{ weight = $ReWeight }
                Write-Verbose "OSD.$OsdId reweight set to $ReWeight"
            }
        }

        if ($DeviceClass) {
            if ($PSCmdlet.ShouldProcess("OSD.$OsdId", "Set device class to $DeviceClass")) {
                Invoke-CephApi -Endpoint "/api/osd/$OsdId/device_class" -Method PUT -Body @{ device_class = $DeviceClass }
                Write-Verbose "OSD.$OsdId device class set to $DeviceClass"
            }
        }

        Get-CephOSD -OsdId $OsdId
    }
}
