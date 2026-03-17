[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
    Import-Module 'PSCeph' -Force

    # Setup mock session for all tests
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

Describe 'Get-CephHealth' {
    BeforeAll {
        Mock Invoke-CephApi {
            @{
                health = @{
                    status = 'HEALTH_OK'
                    checks = @{}
                    mutes  = @()
                }
            }
        } -ModuleName PSCeph
    }

    It 'Should return health status' {
        $result = Get-CephHealth
        $result | Should -Not -BeNullOrEmpty
        $result.Status | Should -Be 'HEALTH_OK'
    }

    It 'Should have PSTypeName PSCeph.Health' {
        $result = Get-CephHealth
        $result.PSObject.TypeNames | Should -Contain 'PSCeph.Health'
    }

    It 'Should support -Full switch' {
        $cmd = Get-Command Get-CephHealth
        $cmd.Parameters['Full'].SwitchParameter | Should -Be $true
    }

    It 'Should call minimal endpoint by default' {
        Get-CephHealth
        Should -Invoke Invoke-CephApi -ParameterFilter { $Endpoint -eq '/api/health/minimal' }
    }

    It 'Should call full endpoint with -Full' {
        Mock Invoke-CephApi {
            @{
                health     = @{ status = 'HEALTH_OK'; checks = @{}; mutes = @() }
                mon_status = @{}
                osd_map    = @{}
                mgr_map    = @{}
                fs_map     = @{}
                hosts      = 3
                pools      = 5
            }
        }

        Get-CephHealth -Full
        Should -Invoke Invoke-CephApi -ParameterFilter { $Endpoint -eq '/api/health/full' }
    }
}

Describe 'Get-CephStatus' {
    BeforeAll {
        Mock Invoke-CephApi {
            @{
                fsid   = 'abc-123-def-456'
                status = 'HEALTH_OK'
            }
        }
    }

    It 'Should return cluster status' {
        $result = Get-CephStatus
        $result | Should -Not -BeNullOrEmpty
        $result.FSID | Should -Be 'abc-123-def-456'
    }

    It 'Should have PSTypeName PSCeph.ClusterStatus' {
        $result = Get-CephStatus
        $result.PSObject.TypeNames | Should -Contain 'PSCeph.ClusterStatus'
    }
}

Describe 'Get-CephConfig' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{ name = 'mon_allow_pool_delete'; value = 'false'; source = 'default' }
                @{ name = 'osd_pool_default_size'; value = '3'; source = 'mon' }
            )
        }
    }

    It 'Should return config options' {
        $result = Get-CephConfig
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -BeGreaterOrEqual 1
    }

    It 'Should filter by Name parameter' {
        $result = Get-CephConfig -Name 'mon*'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -BeLike 'mon*'
    }

    It 'Should have PSTypeName PSCeph.Config' {
        $result = Get-CephConfig
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.Config'
    }
}

Describe 'Get-CephHost' {
    BeforeAll {
        Mock Invoke-CephApi {
            param($Endpoint)
            if ($Endpoint -like '/api/host/*') {
                @{
                    hostname = 'ceph-node1'
                    services = @(@{ type = 'osd'; id = '0' })
                    labels   = @('osd', '_admin')
                    status   = 'OK'
                    addr     = '192.168.1.10'
                }
            }
            else {
                @(
                    @{ hostname = 'ceph-node1'; services = @(); labels = @('osd'); status = 'OK'; addr = '192.168.1.10' }
                    @{ hostname = 'ceph-node2'; services = @(); labels = @('mon'); status = 'OK'; addr = '192.168.1.11' }
                )
            }
        }
    }

    It 'Should return all hosts' {
        $result = Get-CephHost
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should return specific host by name' {
        $result = Get-CephHost -Hostname 'ceph-node1'
        $result | Should -Not -BeNullOrEmpty
        $result.Hostname | Should -Be 'ceph-node1'
    }

    It 'Should have PSTypeName PSCeph.Host' {
        $result = Get-CephHost
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.Host'
    }

    It 'Should support pipeline input' {
        $cmd = Get-Command Get-CephHost
        $cmd.Parameters['Hostname'].Attributes.ValueFromPipeline | Should -Be $true
    }
}

Describe 'Get-CephHostDevice' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    path                = '/dev/sda'
                    device_id           = 'VBOX_HARDDISK_VB12345'
                    human_readable_type = 'hdd'
                    human_readable_size = '100 GB'
                    sys_api             = @{ size = 107374182400; vendor = 'ATA'; model = 'VBOX' }
                    available           = $true
                    rejected_reasons    = @()
                    osd_ids             = @()
                }
            )
        }
    }

    It 'Should require Hostname parameter' {
        $cmd = Get-Command Get-CephHostDevice
        $cmd.Parameters['Hostname'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return devices for a host' {
        $result = Get-CephHostDevice -Hostname 'ceph-node1'
        $result | Should -Not -BeNullOrEmpty
        $result.Path | Should -Be '/dev/sda'
    }

    It 'Should have PSTypeName PSCeph.HostDevice' {
        $result = Get-CephHostDevice -Hostname 'ceph-node1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.HostDevice'
    }
}

Describe 'Get-CephHostDaemon' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    daemon_type = 'osd'
                    daemon_id   = '0'
                    daemon_name = 'osd.0'
                    status      = 1
                    status_desc = 'running'
                    version     = '18.0.0'
                }
            )
        }
    }

    It 'Should require Hostname parameter' {
        $cmd = Get-Command Get-CephHostDaemon
        $cmd.Parameters['Hostname'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return daemons for a host' {
        $result = Get-CephHostDaemon -Hostname 'ceph-node1'
        $result | Should -Not -BeNullOrEmpty
        $result.DaemonType | Should -Be 'osd'
    }

    It 'Should have PSTypeName PSCeph.HostDaemon' {
        $result = Get-CephHostDaemon -Hostname 'ceph-node1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.HostDaemon'
    }
}
