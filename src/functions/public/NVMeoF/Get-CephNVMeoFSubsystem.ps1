function Get-CephNVMeoFSubsystem {
    <#
    .SYNOPSIS
        Gets NVMe-oF subsystems

    .DESCRIPTION
        Retrieves information about NVMe over Fabrics subsystems,
        including NQN, namespaces, and host access configuration.

    .PARAMETER Nqn
        The NQN (NVMe Qualified Name) of a specific subsystem.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephNVMeoFSubsystem
        Returns all NVMe-oF subsystems.

    .EXAMPLE
        Get-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        Returns a specific subsystem.

    .OUTPUTS
        PSCustomObject[] representing NVMe-oF subsystems.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn', 'Name')]
        [string]$Nqn,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint '/api/nvmeof/subsystem'

        if ($Raw) {
            if ($Nqn) {
                return $response | Where-Object { $_.nqn -eq $Nqn }
            }
            return $response
        }

        $subsystems = foreach ($sub in $response) {
            [PSCustomObject]@{
                PSTypeName     = 'PSCeph.NVMeoFSubsystem'
                Nqn            = $sub.nqn
                SubType        = $sub.subtype
                SerialNumber   = $sub.serial_number
                Model          = $sub.model_number
                MaxNamespaces  = $sub.max_namespaces
                MinCtrlrs      = $sub.min_cntlid
                MaxCtrlrs      = $sub.max_cntlid
                Namespaces     = $sub.namespaces
                NamespaceCount = ($sub.namespaces | Measure-Object).Count
                AllowAnyHost   = $sub.allow_any_host
                Hosts          = $sub.hosts
                Listeners      = $sub.listeners
            }
        }

        if ($Nqn) {
            $subsystems | Where-Object { $_.Nqn -eq $Nqn }
        }
        else {
            $subsystems
        }
    }
}
