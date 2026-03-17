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

Describe 'Get-CephRBDImage' {
    BeforeAll {
        Mock Invoke-CephApi {
            param($Endpoint)
            if ($Endpoint -like '/api/block/image/*/*') {
                @{
                    name              = 'testimage'
                    pool_name         = 'rbd'
                    namespace         = ''
                    id                = 'abc123'
                    size              = 10737418240
                    obj_size          = 4194304
                    num_objs          = 2560
                    features_name     = @('layering', 'exclusive-lock')
                    features          = 61
                    snapshots         = @()
                    block_name_prefix = 'rbd_data.abc123'
                }
            }
            else {
                @{
                    value = @(
                        @{ name = 'image1'; pool_name = 'rbd'; size = 10737418240; id = 'abc123' }
                        @{ name = 'image2'; pool_name = 'rbd'; size = 21474836480; id = 'def456' }
                    )
                }
            }
        }
    }

    It 'Should return all images' {
        $result = Get-CephRBDImage -PoolName 'rbd'
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should return specific image' {
        $result = Get-CephRBDImage -PoolName 'rbd' -ImageName 'testimage'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'testimage'
    }

    It 'Should have PSTypeName PSCeph.RBDImage' {
        $result = Get-CephRBDImage -PoolName 'rbd'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.RBDImage'
    }

    It 'Should support Limit parameter' {
        $cmd = Get-Command Get-CephRBDImage
        $cmd.Parameters['Limit'] | Should -Not -BeNullOrEmpty
        $validateRange = $cmd.Parameters['Limit'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
        $validateRange.MinRange | Should -Be 1
        $validateRange.MaxRange | Should -Be 10000
    }

    It 'Should support Offset parameter' {
        $cmd = Get-Command Get-CephRBDImage
        $cmd.Parameters['Offset'] | Should -Not -BeNullOrEmpty
    }

    It 'Should include limit and offset in query' {
        Get-CephRBDImage -PoolName 'rbd' -Limit 50 -Offset 10
        Should -Invoke Invoke-CephApi -ParameterFilter { $Endpoint -like '*limit=50*' -and $Endpoint -like '*offset=10*' }
    }
}

Describe 'New-CephRBDImage' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephRBDImage {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.RBDImage'
                Name       = 'newimage'
                PoolName   = 'rbd'
                Size       = 10737418240
            }
        }
    }

    It 'Should have mandatory PoolName parameter' {
        $cmd = Get-Command New-CephRBDImage
        $cmd.Parameters['PoolName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ImageName parameter' {
        $cmd = Get-Command New-CephRBDImage
        $cmd.Parameters['ImageName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory Size parameter' {
        $cmd = Get-Command New-CephRBDImage
        $cmd.Parameters['Size'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephRBDImage
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should create image with POST request' {
        New-CephRBDImage -PoolName 'rbd' -ImageName 'newimage' -Size 10GB -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}

Describe 'Remove-CephRBDImage' {
    BeforeAll {
        Mock Invoke-CephApi { }
    }

    It 'Should have mandatory PoolName parameter' {
        $cmd = Get-Command Remove-CephRBDImage
        $cmd.Parameters['PoolName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ImageName parameter' {
        $cmd = Get-Command Remove-CephRBDImage
        $cmd.Parameters['ImageName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have ConfirmImpact High' {
        $cmd = Get-Command Remove-CephRBDImage
        $cmdletBinding = $cmd.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
        $cmdletBinding.ConfirmImpact | Should -Be 'High'
    }

    It 'Should delete image with DELETE request' {
        Remove-CephRBDImage -PoolName 'rbd' -ImageName 'testimage' -Force
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'DELETE' }
    }
}

Describe 'Get-CephRBDSnapshot' {
    BeforeAll {
        Mock Get-CephRBDImage {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.RBDImage'
                Name       = 'testimage'
                PoolName   = 'rbd'
                Snapshots  = @(
                    @{ name = 'snap1'; id = 1; size = 10737418240; is_protected = $false }
                    @{ name = 'snap2'; id = 2; size = 10737418240; is_protected = $true }
                )
            }
        }
    }

    It 'Should have mandatory PoolName parameter' {
        $cmd = Get-Command Get-CephRBDSnapshot
        $cmd.Parameters['PoolName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ImageName parameter' {
        $cmd = Get-Command Get-CephRBDSnapshot
        $cmd.Parameters['ImageName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should return snapshots' {
        $result = Get-CephRBDSnapshot -PoolName 'rbd' -ImageName 'testimage'
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should have PSTypeName PSCeph.RBDSnapshot' {
        $result = Get-CephRBDSnapshot -PoolName 'rbd' -ImageName 'testimage'
        $result[0].PSObject.TypeNames | Should -Contain 'PSCeph.RBDSnapshot'
    }

    It 'Should filter by snapshot name' {
        $result = Get-CephRBDSnapshot -PoolName 'rbd' -ImageName 'testimage' -SnapshotName 'snap1'
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be 'snap1'
    }
}

Describe 'New-CephRBDSnapshot' {
    BeforeAll {
        Mock Invoke-CephApi { }
        Mock Get-CephRBDSnapshot {
            [PSCustomObject]@{
                PSTypeName  = 'PSCeph.RBDSnapshot'
                Name        = 'newsnap'
                PoolName    = 'rbd'
                ImageName   = 'testimage'
                IsProtected = $false
            }
        }
    }

    It 'Should have mandatory PoolName parameter' {
        $cmd = Get-Command New-CephRBDSnapshot
        $cmd.Parameters['PoolName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory ImageName parameter' {
        $cmd = Get-Command New-CephRBDSnapshot
        $cmd.Parameters['ImageName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should have mandatory SnapshotName parameter' {
        $cmd = Get-Command New-CephRBDSnapshot
        $cmd.Parameters['SnapshotName'].Attributes.Mandatory | Should -Be $true
    }

    It 'Should support ShouldProcess' {
        $cmd = Get-Command New-CephRBDSnapshot
        $cmd.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        $cmd.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
    }

    It 'Should create snapshot with POST request' {
        New-CephRBDSnapshot -PoolName 'rbd' -ImageName 'testimage' -SnapshotName 'newsnap' -Confirm:$false
        Should -Invoke Invoke-CephApi -ParameterFilter { $Method -eq 'POST' }
    }
}
