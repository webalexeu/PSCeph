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

Describe 'Get-CephNVMeoFGateway' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    name         = 'nvmeof-gw1'
                    group        = 'default'
                    addr         = '192.168.1.100'
                    port         = 4420
                    state        = 'available'
                    availability = 'online'
                    pool         = 'nvmeof-pool'
                }
            )
        } -ModuleName PSCeph
    }

    It 'Should return all gateways' {
        $result = Get-CephNVMeoFGateway
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should filter by gateway name' {
        $result = Get-CephNVMeoFGateway -GatewayName 'nvmeof-gw1'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'nvmeof-gw1'
    }

    It 'Should have PSTypeName PSCeph.NVMeoFGateway' {
        $result = Get-CephNVMeoFGateway
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.NVMeoFGateway'
    }
}

Describe 'Get-CephNVMeoFSubsystem' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    nqn            = 'nqn.2024-01.io.ceph:subsystem1'
                    subtype        = 'NVMe'
                    serial_number  = 'CEPH0001'
                    model_number   = 'Ceph NVMe'
                    max_namespaces = 256
                    namespaces     = @()
                    allow_any_host = $false
                    hosts          = @()
                }
            )
        } -ModuleName PSCeph
    }

    It 'Should return all subsystems' {
        $result = Get-CephNVMeoFSubsystem
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should filter by NQN' {
        $result = Get-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:subsystem1'
        $result | Should -Not -BeNullOrEmpty
        $result.Nqn | Should -Be 'nqn.2024-01.io.ceph:subsystem1'
    }

    It 'Should have PSTypeName PSCeph.NVMeoFSubsystem' {
        $result = Get-CephNVMeoFSubsystem
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.NVMeoFSubsystem'
    }
}

Describe 'New-CephNVMeoFSubsystem' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
        Mock Get-CephNVMeoFSubsystem {
            [PSCustomObject]@{
                PSTypeName    = 'PSCeph.NVMeoFSubsystem'
                Nqn           = 'nqn.2024-01.io.ceph:newsub'
                MaxNamespaces = 256
            }
        }
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command New-CephNVMeoFSubsystem
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephNVMeoFSubsystem
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should create subsystem with POST request' {
        New-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:newsub' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}

Describe 'Remove-CephNVMeoFSubsystem' {
    BeforeAll {
        Mock Invoke-CephApi { }
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Remove-CephNVMeoFSubsystem
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephNVMeoFSubsystem
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }

    It 'Should delete subsystem with DELETE request' {
        Remove-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:testsub' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' }
    }
}

Describe 'Get-CephNVMeoFNamespace' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    nsid           = 1
                    uuid           = 'abc-123'
                    rbd_pool_name  = 'nvmeof-pool'
                    rbd_image_name = 'volume1'
                    rbd_image_size = 10737418240
                    block_size     = 512
                }
            )
        } -ModuleName PSCeph
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Get-CephNVMeoFNamespace
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return namespaces' {
        $result = Get-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should have PSTypeName PSCeph.NVMeoFNamespace' {
        $result = Get-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:sub1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.NVMeoFNamespace'
    }
}

Describe 'New-CephNVMeoFNamespace' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
        Mock Get-CephNVMeoFNamespace {
            [PSCustomObject]@{
                PSTypeName  = 'PSCeph.NVMeoFNamespace'
                NamespaceId = 1
                PoolName    = 'nvmeof-pool'
                ImageName   = 'volume1'
            }
        }
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command New-CephNVMeoFNamespace
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory PoolName parameter' {
        $cmd = Get-Command New-CephNVMeoFNamespace
        $cmd.Parameters['PoolName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ImageName parameter' {
        $cmd = Get-Command New-CephNVMeoFNamespace
        $cmd.Parameters['ImageName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephNVMeoFNamespace
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }
}

Describe 'Remove-CephNVMeoFNamespace' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Remove-CephNVMeoFNamespace
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory NamespaceId parameter' {
        $cmd = Get-Command Remove-CephNVMeoFNamespace
        $cmd.Parameters['NamespaceId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephNVMeoFNamespace
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }
}

Describe 'Get-CephNVMeoFHost' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{ nqn = 'nqn.2024-01.io.host:initiator1' }
                @{ nqn = 'nqn.2024-01.io.host:initiator2' }
            )
        } -ModuleName PSCeph
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Get-CephNVMeoFHost
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return allowed hosts' {
        $result = Get-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1'
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should have PSTypeName PSCeph.NVMeoFHost' {
        $result = Get-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.NVMeoFHost'
    }
}

Describe 'Add-CephNVMeoFHost' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Add-CephNVMeoFHost
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory HostNqn parameter' {
        $cmd = Get-Command Add-CephNVMeoFHost
        $cmd.Parameters['HostNqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command Add-CephNVMeoFHost
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }

    It 'Should add host with POST request' {
        Add-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1' -HostNqn 'nqn.2024-01.io.host:new' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}

Describe 'Remove-CephNVMeoFHost' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
    }

    It 'Should have mandatory Nqn parameter' {
        $cmd = Get-Command Remove-CephNVMeoFHost
        $cmd.Parameters['Nqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory HostNqn parameter' {
        $cmd = Get-Command Remove-CephNVMeoFHost
        $cmd.Parameters['HostNqn'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact Medium' {
        $cmd = Get-Command Remove-CephNVMeoFHost
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'Medium'
    }

    It 'Should delete host with DELETE request' {
        Remove-CephNVMeoFHost -Nqn 'nqn.2024-01.io.ceph:sub1' -HostNqn 'nqn.2024-01.io.host:old' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' }
    }
}
