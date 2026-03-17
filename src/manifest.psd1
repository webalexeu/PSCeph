#
# Module manifest for module 'PSCeph' (override any of the framework defaults and generated values)
#

@{
    GUID                 = 'a8e7f4c3-b5d2-4e6a-9f8c-1d3e5b7a9c2f'
    Author               = 'Alexandre JARDON'
    CompanyName          = 'WebalexEU'
    Copyright            = 'Copyright (c) 2026 Alexandre JARDON (WebalexEU). All rights reserved.'
    Description          = 'PowerShell module for managing Ceph clusters through the Ceph Dashboard REST API.'
    PowerShellVersion    = '5.1'
    # Supported PSEditions
    CompatiblePSEditions = @(
        'PSEdition_Desktop',
        'PSEdition_Core',
        'Windows',
        'Linux',
        'MacOS'
    )
    PrivateData          = @{
        PSData = @{
            Tags                     = @('Ceph', 'Storage', 'RBD', 'CephFS', 'NVMeoF', 'SMB', 'Dashboard', 'API')
            LicenseUri               = 'https://github.com/PSCeph/PSCeph/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/PSCeph/PSCeph'
            ReleaseNotes             = 'Initial release of PSCeph module for Ceph Dashboard API management.'
            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            RequireLicenseAcceptance = $false
        }
    }
}
