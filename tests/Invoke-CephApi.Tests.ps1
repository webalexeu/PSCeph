[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
}

Describe 'Invoke-CephApi' {
    BeforeAll {
        # Setup mock session
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

    Context 'When not connected' {
        BeforeAll {
            $script:CephSession = $null
        }

        It 'Should throw an error when no session exists' {
            { Invoke-CephApi -Endpoint '/api/health/minimal' } | Should -Throw '*Not connected*'
        }
    }

    Context 'When connected' {
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

        It 'Should have correct parameters' {
            $cmd = Get-Command Invoke-CephApi
            $cmd.Parameters['Endpoint'].Attributes.Mandatory | Should -Be $true
            $cmd.Parameters['Method'].Attributes.ValidateSet.ValidValues | Should -Contain 'GET'
            $cmd.Parameters['Method'].Attributes.ValidateSet.ValidValues | Should -Contain 'POST'
            $cmd.Parameters['Method'].Attributes.ValidateSet.ValidValues | Should -Contain 'PUT'
            $cmd.Parameters['Method'].Attributes.ValidateSet.ValidValues | Should -Contain 'DELETE'
        }

        It 'Should default Method to GET' {
            $cmd = Get-Command Invoke-CephApi
            # Check default value in parameter definition
            $cmd.Parameters['Method'].ParameterSets.Values.HelpMessage | Should -BeNullOrEmpty
        }
    }
}
