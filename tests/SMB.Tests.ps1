[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
    $ModulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module "$ModulePath/PSCeph/src/PSCeph.psd1" -Force

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

Describe 'Get-CephSMBCluster' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    cluster_id         = 'smb1'
                    auth_mode          = 'user'
                    domain_settings    = $null
                    user_group_settings = @{}
                    placement          = 'label:smb'
                    clustering         = 'default'
                    shares             = @()
                }
            )
        }
    }

    It 'Should return all SMB clusters' {
        $result = Get-CephSMBCluster
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should filter by ClusterId' {
        $result = Get-CephSMBCluster -ClusterId 'smb1'
        $result | Should -Not -BeNullOrEmpty
        $result.ClusterId | Should -Be 'smb1'
    }

    It 'Should have PSTypeName PSCeph.SMBCluster' {
        $result = Get-CephSMBCluster
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.SMBCluster'
    }
}

Describe 'New-CephSMBCluster' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephSMBCluster {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.SMBCluster'
                ClusterId  = 'newsmb'
                AuthMode   = 'user'
            }
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command New-CephSMBCluster
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory AuthMode parameter' {
        $cmd = Get-Command New-CephSMBCluster
        $cmd.Parameters['AuthMode'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should validate AuthMode values' {
        $cmd = Get-Command New-CephSMBCluster
        $validateSet = $cmd.Parameters['AuthMode'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $validateSet.ValidValues | Should -Contain 'user'
        $validateSet.ValidValues | Should -Contain 'active-directory'
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephSMBCluster
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }

    It 'Should create cluster with POST request' {
        New-CephSMBCluster -ClusterId 'newsmb' -AuthMode 'user' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}

Describe 'Remove-CephSMBCluster' {
    BeforeAll {
        Mock Invoke-CephApi { }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Remove-CephSMBCluster
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephSMBCluster
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }

    It 'Should delete cluster with DELETE request' {
        Remove-CephSMBCluster -ClusterId 'testsmb' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' }
    }
}

Describe 'Get-CephSMBShare' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    share_id  = 'data'
                    name      = 'data'
                    cephfs    = @{ volume = 'cephfs'; path = '/data'; subvolume = $null }
                    readonly  = $false
                    browseable = $true
                }
            )
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Get-CephSMBShare
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return shares for a cluster' {
        $result = Get-CephSMBShare -ClusterId 'smb1'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Should filter by ShareName' {
        $result = Get-CephSMBShare -ClusterId 'smb1' -ShareName 'data'
        $result | Should -Not -BeNullOrEmpty
        $result.ShareName | Should -Be 'data'
    }

    It 'Should have PSTypeName PSCeph.SMBShare' {
        $result = Get-CephSMBShare -ClusterId 'smb1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.SMBShare'
    }
}

Describe 'New-CephSMBShare' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephSMBShare {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.SMBShare'
                ClusterId  = 'smb1'
                ShareName  = 'newshare'
                Path       = '/newshare'
            }
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command New-CephSMBShare
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ShareName parameter' {
        $cmd = Get-Command New-CephSMBShare
        $cmd.Parameters['ShareName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory Filesystem parameter' {
        $cmd = Get-Command New-CephSMBShare
        $cmd.Parameters['Filesystem'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory Path parameter' {
        $cmd = Get-Command New-CephSMBShare
        $cmd.Parameters['Path'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephSMBShare
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }

    It 'Should create share with POST request' {
        New-CephSMBShare -ClusterId 'smb1' -ShareName 'newshare' -Filesystem 'cephfs' -Path '/newshare' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}

Describe 'Set-CephSMBShare' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephSMBShare {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.SMBShare'
                ClusterId  = 'smb1'
                ShareName  = 'data'
                ReadOnly   = $true
            }
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Set-CephSMBShare
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ShareName parameter' {
        $cmd = Get-Command Set-CephSMBShare
        $cmd.Parameters['ShareName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command Set-CephSMBShare
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }

    It 'Should modify share with PUT request' {
        Set-CephSMBShare -ClusterId 'smb1' -ShareName 'data' -ReadOnly $true -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'PUT' }
    }
}

Describe 'Remove-CephSMBShare' {
    BeforeAll {
        Mock Invoke-CephApi { }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Remove-CephSMBShare
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ShareName parameter' {
        $cmd = Get-Command Remove-CephSMBShare
        $cmd.Parameters['ShareName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephSMBShare
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }

    It 'Should delete share with DELETE request' {
        Remove-CephSMBShare -ClusterId 'smb1' -ShareName 'testshare' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' }
    }
}

Describe 'Get-CephSMBUserGroup' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{ resource_type = 'users'; name = 'user1'; values = @{} }
                @{ resource_type = 'groups'; name = 'group1'; values = @{} }
            )
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Get-CephSMBUserGroup
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return users and groups' {
        $result = Get-CephSMBUserGroup -ClusterId 'smb1'
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should filter by ResourceType' {
        $result = Get-CephSMBUserGroup -ClusterId 'smb1' -ResourceType 'users'
        $result | Should -Not -BeNullOrEmpty
        $result.ResourceType | Should -Be 'users'
    }

    It 'Should have PSTypeName PSCeph.SMBUserGroup' {
        $result = Get-CephSMBUserGroup -ClusterId 'smb1'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.SMBUserGroup'
    }
}

Describe 'Join-CephSMBActiveDirectory' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephSMBCluster {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.SMBCluster'
                ClusterId  = 'smb1'
                AuthMode   = 'active-directory'
            }
        }
    }

    It 'Should have mandatory ClusterId parameter' {
        $cmd = Get-Command Join-CephSMBActiveDirectory
        $cmd.Parameters['ClusterId'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory DomainRealm parameter' {
        $cmd = Get-Command Join-CephSMBActiveDirectory
        $cmd.Parameters['DomainRealm'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory Credential parameter' {
        $cmd = Get-Command Join-CephSMBActiveDirectory
        $cmd.Parameters['Credential'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command Join-CephSMBActiveDirectory
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
    }

    It 'Should join domain with PUT request' {
        $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
        Join-CephSMBActiveDirectory -ClusterId 'smb1' -DomainRealm 'CORP.LOCAL' -Credential $cred -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'PUT' }
    }
}
