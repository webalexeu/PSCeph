function Remove-CephNVMeoFSubsystem {
    <#
    .SYNOPSIS
        Removes an NVMe-oF subsystem

    .DESCRIPTION
        Deletes an NVMe over Fabrics subsystem and all associated
        namespaces and host mappings.

    .PARAMETER Nqn
        The NQN of the subsystem to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        Removes the specified subsystem.

    .EXAMPLE
        Get-CephNVMeoFSubsystem | Where-Object Nqn -like '*test*' | Remove-CephNVMeoFSubsystem -Force
        Removes all test subsystems without confirmation.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn', 'Name')]
        [string]$Nqn,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess($Nqn, 'Remove NVMe-oF subsystem')) {
            $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
            Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn" -Method DELETE
            Write-Verbose "NVMe-oF subsystem '$Nqn' has been removed."
        }
    }
}
