function Remove-CephNVMeoFNamespace {
    <#
    .SYNOPSIS
        Removes an NVMe-oF namespace.

    .DESCRIPTION
        Deletes a namespace from an NVMe-oF subsystem. The underlying
        RBD image is not deleted.

    .PARAMETER Nqn
        The NQN of the subsystem containing the namespace.

    .PARAMETER NamespaceId
        The namespace ID to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1' -NamespaceId 1
        Removes namespace 1 from the subsystem.

    .EXAMPLE
        Get-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1' | Remove-CephNVMeoFNamespace -Force
        Removes all namespaces from the subsystem.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Nsid')]
        [int]$NamespaceId,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess("$Nqn/namespace/$NamespaceId", 'Remove NVMe-oF namespace')) {
            $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
            Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/namespace/$NamespaceId" -Method DELETE
            Write-Verbose "NVMe-oF namespace $NamespaceId removed from '$Nqn'."
        }
    }
}
