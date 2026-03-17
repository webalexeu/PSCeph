@{
    ModuleVersion     = '0.1.0'
    GUID              = 'a8e7f4c3-b5d2-4e6a-9f8c-1d3e5b7a9c2f'
    Author            = 'Alexandre JARDON'
    CompanyName       = 'WebalexEU'
    Copyright         = 'Copyright (c) 2026 Alexandre JARDON (WebalexEU). All rights reserved.'
    Description       = 'PowerShell module for managing Ceph clusters through the Ceph Dashboard REST API.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        # Connection
        'Connect-Ceph'
        'Disconnect-Ceph'
        'Get-CephConnection'

        # Cluster
        'Get-CephHealth'
        'Get-CephStatus'
        'Get-CephConfig'
        'Get-CephHost'
        'Get-CephHostDevice'
        'Get-CephHostDaemon'

        # Pool
        'Get-CephPool'
        'New-CephPool'
        'Set-CephPool'
        'Remove-CephPool'

        # OSD
        'Get-CephOSD'
        'Set-CephOSD'
        'Get-CephOSDTree'

        # Monitor
        'Get-CephMonitor'

        # RBD
        'Get-CephRBDImage'
        'New-CephRBDImage'
        'Remove-CephRBDImage'
        'Get-CephRBDSnapshot'
        'New-CephRBDSnapshot'

        # CephFS
        'Get-CephFS'
        'Get-CephFSDirectory'

        # Auth
        'Get-CephUser'
        'Get-CephDashboardUser'

        # NVMeoF
        'Get-CephNVMeoFGateway'
        'Get-CephNVMeoFSubsystem'
        'New-CephNVMeoFSubsystem'
        'Remove-CephNVMeoFSubsystem'
        'Get-CephNVMeoFNamespace'
        'New-CephNVMeoFNamespace'
        'Remove-CephNVMeoFNamespace'
        'Get-CephNVMeoFHost'
        'Add-CephNVMeoFHost'
        'Remove-CephNVMeoFHost'

        # SMB
        'Get-CephSMBCluster'
        'New-CephSMBCluster'
        'Remove-CephSMBCluster'
        'Get-CephSMBShare'
        'New-CephSMBShare'
        'Set-CephSMBShare'
        'Remove-CephSMBShare'
        'Get-CephSMBUsersGroups'
        'Join-CephSMBActiveDirectory'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Ceph', 'Storage', 'RBD', 'CephFS', 'NVMeoF', 'SMB', 'Dashboard', 'API')
            LicenseUri   = 'https://github.com/PSCeph/PSCeph/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/PSCeph/PSCeph'
            ReleaseNotes = 'Initial release of PSCeph module for Ceph Dashboard API management.'
        }
    }
}
