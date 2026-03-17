[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
    $script:CephSession = [PSCustomObject]@{
        Server               = 'ceph-test.local'
        Port                 = 8443
        BaseUri              = 'https://ceph-test.local:8443'
        Token                = 'test-token-12345'
        TokenExpiry          = (Get-Date).AddHours(1)
        Username             = 'admin'
        SkipCertificateCheck = $true
        ConnectedAt          = Get-Date
        Permissions          = @{}
    }
}

AfterAll {
    $script:CephSession = $null
}

Describe 'Get-CephFS' {
    BeforeAll {
        Mock Invoke-CephApi {
            param($Endpoint)
            if ($Endpoint -like '/api/cephfs/*') {
                @{
                    cephfs = @{
                        name             = 'cephfs'
                        id               = 1
                        metadata_pool    = 'cephfs_metadata'
                        metadata_pool_id = 1
                        data_pools       = @('cephfs_data')
                        data_pool_ids    = @(2)
                    }
                    standbys     = @()
                    clients      = @{ count = 5; data = @() }
                    mds_counters = @{}
                }
            }
            else {
                @(
                    @{
                        mdsmap = @{
                            fs_name               = 'cephfs'
                            metadata_pool         = 1
                            data_pools            = @(2)
                            max_mds               = 1
                            in                    = @(0)
                            up                    = @{ 'mds_0' = 12345 }
                            standby_count_wanted  = 1
                        }
                        id = 1
                    }
                )
            }
        } -ModuleName PSCeph
    }

    It 'Should return all filesystems' {
        $result = Get-CephFS
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should return specific filesystem by name' {
        $result = Get-CephFS -Name 'cephfs'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'cephfs'
    }

    It 'Should have PSTypeName PSCeph.CephFS' {
        $result = Get-CephFS
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.CephFS'
    }

    It 'Should support pipeline input' {
        $cmd = Get-Command Get-CephFS
        $cmd.Parameters['Name'].Attributes.ValueFromPipeline | Should -Be $true
    }
}

Describe 'Get-CephFSDirectory' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    name        = 'data'
                    path        = '/data'
                    is_dir      = $true
                    uid         = 0
                    gid         = 0
                    mode        = 16877
                    mode_string = 'drwxr-xr-x'
                    size        = 4096
                    mtime       = '2024-01-01T00:00:00'
                }
                @{
                    name        = 'backup'
                    path        = '/backup'
                    is_dir      = $true
                    uid         = 0
                    gid         = 0
                    mode        = 16877
                    mode_string = 'drwxr-xr-x'
                    size        = 4096
                }
            )
        }
    }

    It 'Should have mandatory Filesystem parameter' {
        $cmd = Get-Command Get-CephFSDirectory
        $cmd.Parameters['Filesystem'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return directories' {
        $result = Get-CephFSDirectory -Filesystem 'cephfs'
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should have PSTypeName PSCeph.CephFSDirectory' {
        $result = Get-CephFSDirectory -Filesystem 'cephfs'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.CephFSDirectory'
    }

    It 'Should default Path to root' {
        Get-CephFSDirectory -Filesystem 'cephfs'
        Should -Invoke Invoke-CephApi -ParameterFilter { $Endpoint -like '*path=%2F*' -or $Endpoint -like '*path=/*' }
    }
}

Describe 'Get-CephUser' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    entity = 'client.admin'
                    caps   = @{ mon = 'allow *'; osd = 'allow *'; mgr = 'allow *' }
                    key    = 'AQBxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=='
                }
                @{
                    entity = 'client.rbd'
                    caps   = @{ mon = 'profile rbd'; osd = 'profile rbd pool=rbd' }
                    key    = 'AQByyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy=='
                }
            )
        }
    }

    It 'Should return all users' {
        $result = Get-CephUser
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should filter by user name' {
        $result = Get-CephUser -Name 'client.admin'
        $result | Should -Not -BeNullOrEmpty
        $result.Entity | Should -Be 'client.admin'
    }

    It 'Should have PSTypeName PSCeph.User' {
        $result = Get-CephUser
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.User'
    }
}

Describe 'Get-CephDashboardUser' {
    BeforeAll {
        Mock Invoke-CephApi {
            param($Endpoint)
            if ($Endpoint -like '/api/user/*') {
                @{
                    username            = 'admin'
                    name                = 'Administrator'
                    email               = 'admin@example.com'
                    roles               = @('administrator')
                    last_update         = (Get-Date).ToString()
                    enabled             = $true
                    pwd_expiration_date = $null
                    pwd_update_required = $false
                }
            }
            else {
                @(
                    @{ username = 'admin'; name = 'Administrator'; roles = @('administrator'); enabled = $true }
                    @{ username = 'viewer'; name = 'Viewer User'; roles = @('read-only'); enabled = $true }
                )
            }
        }
    }

    It 'Should return all dashboard users' {
        $result = Get-CephDashboardUser
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should return specific user by username' {
        $result = Get-CephDashboardUser -Username 'admin'
        $result | Should -Not -BeNullOrEmpty
        $result.Username | Should -Be 'admin'
    }

    It 'Should have PSTypeName PSCeph.DashboardUser' {
        $result = Get-CephDashboardUser
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.DashboardUser'
    }
}
