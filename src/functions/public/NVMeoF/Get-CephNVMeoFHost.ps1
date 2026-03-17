function Get-CephNVMeoFHost {
    <#
    .SYNOPSIS
        Gets hosts allowed to access an NVMe-oF subsystem

    .DESCRIPTION
        Retrieves the list of host NQNs that are allowed to connect
        to a specific NVMe-oF subsystem.

    .PARAMETER Nqn
        The NQN of the subsystem.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        Returns all allowed hosts for the subsystem.

    .EXAMPLE
        Get-CephNVMeoFSubsystem | Get-CephNVMeoFHost
        Returns allowed hosts for all subsystems.

    .OUTPUTS
        PSCustomObject[] representing allowed hosts.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
        $response = Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/host"

        if ($Raw) {
            return $response
        }

        foreach ($hostEntry in $response) {
            [PSCustomObject]@{
                PSTypeName   = 'PSCeph.NVMeoFHost'
                SubsystemNqn = $Nqn
                HostNqn      = $hostEntry.nqn
            }
        }
    }
}
