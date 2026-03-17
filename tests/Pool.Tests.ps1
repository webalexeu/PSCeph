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

Describe 'Get-CephPool' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(
                @{
                    pool_name           = 'rbd'
                    pool                = 1
                    type                = 'replicated'
                    size                = 3
                    min_size            = 2
                    pg_num              = 32
                    pg_placement_num    = 32
                    pg_autoscale_mode   = 'on'
                    crush_rule          = 0
                    application_metadata = @{ rbd = @{} }
                    stats               = @{ bytes_used = 1073741824; max_avail = 10737418240 }
                }
                @{
                    pool_name           = 'cephfs_data'
                    pool                = 2
                    type                = 'replicated'
                    size                = 3
                    min_size            = 2
                    pg_num              = 64
                    pg_placement_num    = 64
                    pg_autoscale_mode   = 'on'
                }
            )
        } -ModuleName PSCeph
    }

    It 'Should return all pools' {
        $result = Get-CephPool
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should filter by pool name' {
        $result = Get-CephPool -Name 'rbd'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'rbd'
    }

    It 'Should have PSTypeName PSCeph.Pool' {
        $result = Get-CephPool
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.Pool'
    }

    It 'Should support -Stats switch' {
        $cmd = Get-Command Get-CephPool
        $cmd.Parameters['Stats'].SwitchParameter | Should -Be $true
    }

    It 'Should support pipeline input' {
        $cmd = Get-Command Get-CephPool
        $cmd.Parameters['Name'].Attributes.ValueFromPipeline | Should -Be $true
    }
}

Describe 'New-CephPool' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
        Mock Get-CephPool {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.Pool'
                Name       = 'newpool'
                Size       = 3
                PgNum      = 32
            }
        }
    }

    It 'Should have mandatory Name parameter' {
        $cmd = Get-Command New-CephPool
        $cmd.Parameters['Name'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephPool
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should validate PoolType values' {
        $cmd = Get-Command New-CephPool
        $validateSet = $cmd.Parameters['PoolType'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $validateSet.ValidValues | Should -Contain 'replicated'
        $validateSet.ValidValues | Should -Contain 'erasure'
    }

    It 'Should validate Size range 1-10' {
        $cmd = Get-Command New-CephPool
        $validateRange = $cmd.Parameters['Size'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $validateRange.MinRange | Should -Be 1
        $validateRange.MaxRange | Should -Be 10
    }

    It 'Should create pool with default settings' {
        $result = New-CephPool -Name 'newpool' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' } -ModuleName PSCeph
    }
}

Describe 'Set-CephPool' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
        Mock Get-CephPool {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.Pool'
                Name       = 'rbd'
                Size       = 2
            }
        }
    }

    It 'Should have mandatory Name parameter' {
        $cmd = Get-Command Set-CephPool
        $cmd.Parameters['Name'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command Set-CephPool
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should modify pool with PUT request' {
        Set-CephPool -Name 'rbd' -Size 2 -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'PUT' } -ModuleName PSCeph
    }
}

Describe 'Remove-CephPool' {
    BeforeAll {
        Mock Invoke-CephApi { } -ModuleName PSCeph
    }

    It 'Should have mandatory Name parameter' {
        $cmd = Get-Command Remove-CephPool
        $cmd.Parameters['Name'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephPool
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }

    It 'Should support -Force switch' {
        $cmd = Get-Command Remove-CephPool
        $cmd.Parameters['Force'].SwitchParameter | Should -Be $true
    }

    It 'Should delete pool with DELETE request' {
        Remove-CephPool -Name 'testpool' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' } -ModuleName PSCeph
    }
}
