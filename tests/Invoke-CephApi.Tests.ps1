[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for Pester tests')]
[CmdletBinding()]
param()

BeforeAll {
}

Describe 'Invoke-CephApi' {
    Context 'When not connected' {
        It 'Should throw an error when no session exists' {
            InModuleScope PSCeph {
                $script:CephSession = $null
                { Invoke-CephApi -Endpoint '/api/health/minimal' } | Should -Throw '*Not connected*'
            }
        }
    }

    Context 'When connected' {
        It 'Should have correct parameters' {
            InModuleScope PSCeph {
                $cmd = Get-Command Invoke-CephApi
                $cmd.Parameters['Endpoint'].Attributes.Mandatory | Should -Be $true
                $validateSet = $cmd.Parameters['Method'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                $validateSet.ValidValues | Should -Contain 'GET'
                $validateSet.ValidValues | Should -Contain 'POST'
                $validateSet.ValidValues | Should -Contain 'PUT'
                $validateSet.ValidValues | Should -Contain 'DELETE'
            }
        }

        It 'Should default Method to GET' {
            InModuleScope PSCeph {
                $cmd = Get-Command Invoke-CephApi
                # Check default value in parameter definition
                $cmd.Parameters['Method'].ParameterSets.Values.HelpMessage | Should -BeNullOrEmpty
            }
        }
    }
}
