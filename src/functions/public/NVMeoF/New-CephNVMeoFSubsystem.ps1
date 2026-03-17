function New-CephNVMeoFSubsystem {
    <#
    .SYNOPSIS
        Creates a new NVMe-oF subsystem.

    .DESCRIPTION
        Creates a new NVMe over Fabrics subsystem with the specified
        NQN and configuration.

    .PARAMETER Nqn
        The NQN (NVMe Qualified Name) for the subsystem.

    .PARAMETER MaxNamespaces
        Maximum number of namespaces allowed. Defaults to 256.

    .PARAMETER AllowAnyHost
        Allow any host to connect. Defaults to false for security.

    .PARAMETER SerialNumber
        Optional serial number for the subsystem.

    .PARAMETER Model
        Optional model number for the subsystem.

    .EXAMPLE
        New-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        Creates a new subsystem with the specified NQN.

    .EXAMPLE
        New-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:subsystem1' -AllowAnyHost
        Creates a subsystem allowing any host to connect.

    .OUTPUTS
        PSCustomObject representing the created subsystem.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Alias('SubsystemNqn', 'Name')]
        [string]$Nqn,

        [Parameter()]
        [ValidateRange(1, 1024)]
        [int]$MaxNamespaces = 256,

        [Parameter()]
        [switch]$AllowAnyHost,

        [Parameter()]
        [string]$SerialNumber,

        [Parameter()]
        [string]$Model
    )

    $body = @{
        nqn            = $Nqn
        max_namespaces = $MaxNamespaces
        allow_any_host = $AllowAnyHost.IsPresent
    }

    if ($SerialNumber) { $body['serial_number'] = $SerialNumber }
    if ($Model) { $body['model_number'] = $Model }

    if ($PSCmdlet.ShouldProcess($Nqn, 'Create NVMe-oF subsystem')) {
        Invoke-CephApi -Endpoint '/api/nvmeof/subsystem' -Method POST -Body $body

        Get-CephNVMeoFSubsystem -Nqn $Nqn
    }
}
