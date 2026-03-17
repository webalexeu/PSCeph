function Add-CephNVMeoFHost {
    <#
    .SYNOPSIS
        Adds a host to an NVMe-oF subsystem.

    .DESCRIPTION
        Grants access to an NVMe-oF subsystem for a specific host
        identified by its NQN.

    .PARAMETER Nqn
        The NQN of the subsystem.

    .PARAMETER HostNqn
        The NQN of the host to allow.

    .EXAMPLE
        Add-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1' -HostNqn 'nqn.2024-01.io.host:initiator1'
        Allows the specified host to access the subsystem.

    .EXAMPLE
        $subsystem = Get-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:sub1'
        Add-CephNVMeoFHost -Nqn $subsystem.Nqn -HostNqn 'nqn.2024-01.io.host:initiator1'
        Adds a host using pipeline input.

    .OUTPUTS
        PSCustomObject representing the added host mapping.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter(Mandatory)]
        [string]$HostNqn
    )

    process {
        if ($PSCmdlet.ShouldProcess("$Nqn -> $HostNqn", 'Add host to NVMe-oF subsystem')) {
            $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
            $body = @{ host_nqn = $HostNqn }

            Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/host" -Method POST -Body $body

            [PSCustomObject]@{
                PSTypeName   = 'PSCeph.NVMeoFHost'
                SubsystemNqn = $Nqn
                HostNqn      = $HostNqn
            }
        }
    }
}
