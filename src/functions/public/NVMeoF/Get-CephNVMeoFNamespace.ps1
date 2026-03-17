function Get-CephNVMeoFNamespace {
    <#
    .SYNOPSIS
        Gets NVMe-oF namespaces.

    .DESCRIPTION
        Retrieves namespace information for an NVMe-oF subsystem,
        including the backing RBD image and configuration.

    .PARAMETER Nqn
        The NQN of the subsystem containing the namespaces.

    .PARAMETER NamespaceId
        Optional specific namespace ID to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        Returns all namespaces in the subsystem.

    .EXAMPLE
        Get-CephNVMeoFSubsystem | Get-CephNVMeoFNamespace
        Returns namespaces for all subsystems.

    .OUTPUTS
        PSCustomObject[] representing NVMe-oF namespaces.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('SubsystemNqn')]
        [string]$Nqn,

        [Parameter()]
        [Alias('Nsid')]
        [int]$NamespaceId,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $encodedNqn = [System.Web.HttpUtility]::UrlEncode($Nqn)
        $response = Invoke-CephApi -Endpoint "/api/nvmeof/subsystem/$encodedNqn/namespace"

        if ($Raw) {
            if ($PSBoundParameters.ContainsKey('NamespaceId')) {
                return $response | Where-Object { $_.nsid -eq $NamespaceId }
            }
            return $response
        }

        $namespaces = foreach ($ns in $response) {
            [PSCustomObject]@{
                PSTypeName   = 'PSCeph.NVMeoFNamespace'
                Nqn          = $Nqn
                NamespaceId  = $ns.nsid
                Uuid         = $ns.uuid
                PoolName     = $ns.rbd_pool_name
                ImageName    = $ns.rbd_image_name
                Namespace    = $ns.rbd_namespace
                BlockSize    = $ns.block_size
                Size         = $ns.rbd_image_size
                SizeHuman    = "{0:N2} GB" -f ($ns.rbd_image_size / 1GB)
                NguidEnabled = $ns.nguid
                Anagrpid     = $ns.anagrpid
            }
        }

        if ($PSBoundParameters.ContainsKey('NamespaceId')) {
            $namespaces | Where-Object { $_.NamespaceId -eq $NamespaceId }
        }
        else {
            $namespaces
        }
    }
}
