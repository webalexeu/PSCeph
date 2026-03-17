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

Describe 'Get-CephOSD' {
    BeforeAll {
        Mock Invoke-CephApi {
            param($Endpoint)
            if ($Endpoint -like '/api/osd/*') {
                @{
                    osd          = 0
                    uuid         = 'abc-123'
                    up           = 1
                    in           = 1
                    state        = @('exists', 'up')
                    host         = 'ceph-node1'
                    device_class = 'ssd'
                    num_pgs      = 100
                    crush_weight = 1.0
                    reweight     = 1.0
                }
            }
            else {
                @(
                    @{ osd = 0; uuid = 'abc-123'; up = 1; in = 1; host = 'ceph-node1'; device_class = 'ssd' }
                    @{ osd = 1; uuid = 'def-456'; up = 1; in = 1; host = 'ceph-node2'; device_class = 'ssd' }
                )
            }
        } -ModuleName PSCeph
    }

    It 'Should return all OSDs' {
        $result = Get-CephOSD
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should return specific OSD by ID' {
        $result = Get-CephOSD -OsdId 0
        $result | Should -Not -BeNullOrEmpty
        $result.OsdId | Should -Be 0
    }

    It 'Should have PSTypeName PSCeph.OSD' {
        $result = Get-CephOSD
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.OSD'
    }

    It 'Should calculate Status property' {
        $result = Get-CephOSD -OsdId 0
        $result.Status | Should -Be 'up'
        $result.Up | Should -Be $true
        $result.In | Should -Be $true
    }
}

Describe 'Set-CephOSD' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
        Mock Get-CephOSD {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.OSD'
                OsdId      = 0
                Status     = 'up'
                Up         = $true
                In         = $false
            }
        }
    }

    It 'Should have mandatory OsdId parameter' {
        $cmd = Get-Command Set-CephOSD
        $cmd.Parameters['OsdId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command Set-CephOSD
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should have -In and -Out parameter sets' {
        $cmd = Get-Command Set-CephOSD
        $cmd.Parameters['In'].SwitchParameter | Should -Be $true
        $cmd.Parameters['Out'].SwitchParameter | Should -Be $true
    }

    It 'Should validate ReWeight range 0.0-1.0' {
        $cmd = Get-Command Set-CephOSD
        $validateRange = $cmd.Parameters['ReWeight'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $validateRange.MinRange | Should -Be 0.0
        $validateRange.MaxRange | Should -Be 1.0
    }
}

Describe 'Get-CephOSDTree' {
    BeforeAll {
        Mock Invoke-CephApi {
            @{
                nodes = @(
                    @{ id = -1; name = 'default'; type = 'root'; children = @(-2) }
                    @{ id = -2; name = 'ceph-node1'; type = 'host'; children = @(0, 1) }
                    @{ id = 0; name = 'osd.0'; type = 'osd'; status = 'up'; device_class = 'ssd' }
                    @{ id = 1; name = 'osd.1'; type = 'osd'; status = 'up'; device_class = 'ssd' }
                )
            }
        } -ModuleName PSCeph
    }

    It 'Should return OSD tree' {
        $result = Get-CephOSDTree
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should have PSTypeName PSCeph.OSDTreeNode' {
        $result = Get-CephOSDTree
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.OSDTreeNode'
    }
}

Describe 'Get-CephMonitor' {
    BeforeAll {
        Mock Invoke-CephApi {
            @{
                mon_status = @{
                    monmap = @{
                        mons = @(
                            @{ name = 'mon.a'; rank = 0; addr = '192.168.1.10:6789'; public_addr = '192.168.1.10:6789' }
                            @{ name = 'mon.b'; rank = 1; addr = '192.168.1.11:6789'; public_addr = '192.168.1.11:6789' }
                            @{ name = 'mon.c'; rank = 2; addr = '192.168.1.12:6789'; public_addr = '192.168.1.12:6789' }
                        )
                    }
                    quorum_names = @('mon.a', 'mon.b', 'mon.c')
                }
            }
        } -ModuleName PSCeph
    }

    It 'Should return all monitors' {
        $result = Get-CephMonitor
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 3
    }

    It 'Should filter by monitor name' {
        $result = Get-CephMonitor -Name 'mon.a'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'mon.a'
    }

    It 'Should have PSTypeName PSCeph.Monitor' {
        $result = Get-CephMonitor
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.Monitor'
    }

    It 'Should indicate quorum status' {
        $result = Get-CephMonitor
        $result | ForEach-Object { $_.InQuorum | Should -Be $true }
    }
}
