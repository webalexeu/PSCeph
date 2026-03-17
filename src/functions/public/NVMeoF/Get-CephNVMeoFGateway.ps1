function Get-CephNVMeoFGateway {
    <#
    .SYNOPSIS
        Gets NVMe-oF gateways.

    .DESCRIPTION
        Retrieves information about NVMe over Fabrics gateways in the
        Ceph cluster, including status and configuration.

    .PARAMETER GatewayName
        The name of a specific gateway to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephNVMeoFGateway
        Returns all NVMe-oF gateways.

    .EXAMPLE
        Get-CephNVMeoFGateway -GatewayName 'nvmeof-gw1'
        Returns a specific gateway.

    .OUTPUTS
        PSCustomObject[] representing NVMe-oF gateways.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$GatewayName,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint '/api/nvmeof/gateway'

        if ($Raw) {
            if ($GatewayName) {
                return $response | Where-Object { $_.name -eq $GatewayName }
            }
            return $response
        }

        $gateways = foreach ($gw in $response) {
            [PSCustomObject]@{
                PSTypeName    = 'PSCeph.NVMeoFGateway'
                Name          = $gw.name
                Group         = $gw.group
                Address       = $gw.addr
                Port          = $gw.port
                State         = $gw.state
                Availability  = $gw.availability
                LoadBalancing = $gw.load_balancing_group
                Subsystems    = $gw.subsystems
                PoolName      = $gw.pool
                ServiceUrl    = $gw.service_url
                SpVersion     = $gw.spdk_version
                Version       = $gw.version
            }
        }

        if ($GatewayName) {
            $gateways | Where-Object { $_.Name -eq $GatewayName }
        }
        else {
            $gateways
        }
    }
}
