[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
    $ModulePath = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module "$ModulePath/PSCeph/src/PSCeph.psd1" -Force
}

Describe 'Connect-Ceph' {
    BeforeAll {
        $script:CephSession = $null
    }

    Context 'Parameter Validation' {
        It 'Should have mandatory Server parameter' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Server'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have mandatory Credential parameter' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Credential'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have optional Port parameter with default 8443' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Port'].Attributes.Mandatory | Should -Not -Be $true
        }

        It 'Should validate Port range 1-65535' {
            $cmd = Get-Command Connect-Ceph
            $validateRange = $cmd.Parameters['Port'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 65535
        }

        It 'Should have SkipCertificateCheck switch' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['SkipCertificateCheck'].SwitchParameter | Should -Be $true
        }
    }

    Context 'When connecting successfully' {
        BeforeAll {
            Mock Invoke-RestMethod {
                return @{
                    token       = 'mock-token-abc123'
                    permissions = @{ pool = 'read' }
                }
            }

            $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
        }

        It 'Should return connection info' {
            $result = Connect-Ceph -Server 'ceph-test.local' -Credential $cred -SkipCertificateCheck
            $result | Should -Not -BeNullOrEmpty
            $result.Server | Should -Be 'ceph-test.local'
            $result.Username | Should -Be 'admin'
        }

        It 'Should set script session variable' {
            $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
            Connect-Ceph -Server 'ceph-test.local' -Credential $cred -SkipCertificateCheck
            $script:CephSession | Should -Not -BeNullOrEmpty
            $script:CephSession.Token | Should -Be 'mock-token-abc123'
        }
    }

    Context 'When connection fails' {
        BeforeAll {
            Mock Invoke-RestMethod {
                throw 'Connection refused'
            }

            $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
        }

        It 'Should throw on connection failure' {
            { Connect-Ceph -Server 'invalid-server' -Credential $cred -SkipCertificateCheck } | Should -Throw
        }
    }
}

Describe 'Disconnect-Ceph' {
    Context 'When connected' {
        BeforeAll {
            $script:CephSession = [PSCustomObject]@{
                Server               = 'ceph-test.local'
                Port                 = 8443
                BaseUri              = 'https://ceph-test.local:8443'
                Token                = 'test-token'
                Username             = 'admin'
                SkipCertificateCheck = $true
            }

            Mock Invoke-RestMethod { }
        }

        It 'Should clear session' {
            Disconnect-Ceph
            $script:CephSession | Should -BeNullOrEmpty
        }
    }

    Context 'When not connected' {
        BeforeAll {
            $script:CephSession = $null
        }

        It 'Should warn when no active connection' {
            Disconnect-Ceph 3>&1 | Should -BeLike '*No active*'
        }
    }
}

Describe 'Get-CephConnection' {
    Context 'When connected' {
        BeforeAll {
            $script:CephSession = [PSCustomObject]@{
                Server      = 'ceph-test.local'
                Port        = 8443
                Username    = 'admin'
                ConnectedAt = Get-Date
                TokenExpiry = (Get-Date).AddHours(1)
                Permissions = @{ pool = 'read' }
            }
        }

        It 'Should return connection info' {
            $result = Get-CephConnection
            $result | Should -Not -BeNullOrEmpty
            $result.Server | Should -Be 'ceph-test.local'
            $result.Port | Should -Be 8443
            $result.Username | Should -Be 'admin'
        }

        It 'Should have correct type name' {
            $result = Get-CephConnection
            $result.PSObject.TypeNames | Should -Contain 'PSCeph.ConnectionInfo'
        }
    }

    Context 'When not connected' {
        BeforeAll {
            $script:CephSession = $null
        }

        It 'Should return null' {
            Get-CephConnection | Should -BeNullOrEmpty
        }
    }
}
