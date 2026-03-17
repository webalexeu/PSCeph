function Remove-CephNVMeoFHost {
    <#
    .SYNOPSIS
        Removes a host from an NVMe-oF subsystem

    .DESCRIPTION
        Revokes access to an NVMe-oF subsystem for a specific host.

    .PARAMETER Nqn
        The NQN of the subsystem.

    .PARAMETER HostNqn
        The NQN of the host to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1' -HostNqn 'nqn.2024-01.io.host:initiator1'
        Removes the specified host from the subsystem.

    .EXAMPLE
        Get-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1' | Remove-CephNVMeoFHost -Force
        Removes all hosts from the subsystem.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$HostNqn,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess("$Nqn -> $HostNqn", 'Remove host from NVMe-oF subsystem')) {
            $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
            $encodedHost = [System.Web.HttpUtility]::UrlEncode($HostNqn)

            Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/host/$encodedHost" -Method DELETE
            Write-Verbose "Host '$HostNqn' removed from NVMe-oF subsystem '$Nqn'."
        }
    }
}
