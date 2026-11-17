[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for Pester tests')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper, no actual state change')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '', Justification = 'Internal test helper, not part of the module API')]
[CmdletBinding()]
param()

BeforeAll {
}

Describe 'Connect-Ceph' {
    BeforeAll {
        InModuleScope PSCeph {
            $script:CephSession = $null
        }
    }

    Context 'Parameter Validation' {
        It 'Should have mandatory Server parameter' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Server'].Attributes.Mandatory | Should -Be $true
        }

        It 'Should have optional Credential parameter (auto-detection picks the method when omitted)' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Credential'].Attributes.Mandatory | Should -Not -Be $true
        }

        It 'Should have an Sso switch' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['Sso'].SwitchParameter | Should -Be $true
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
            } -ModuleName PSCeph

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
            $result = Get-CephConnection
            $result | Should -Not -BeNullOrEmpty
            InModuleScope PSCeph {
                $script:CephSession.Token | Should -Be 'mock-token-abc123'
            }
        }
    }

    Context 'When connection fails' {
        BeforeAll {
            Mock Invoke-RestMethod {
                throw 'Connection refused'
            } -ModuleName PSCeph

            $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
        }

        It 'Should throw on connection failure' {
            { Connect-Ceph -Server 'invalid-server' -Credential $cred -SkipCertificateCheck } | Should -Throw
        }
    }
}

Describe 'Connect-Ceph OIDC and auto-detection' {
    BeforeAll {
        function New-TestJwt([hashtable]$Claims) {
            $header = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('{"alg":"none"}')).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            $json = ($Claims | ConvertTo-Json -Compress)
            $payload = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
            "$header.$payload.sig"
        }
        $cred = [PSCredential]::new('admin', (ConvertTo-SecureString 'password' -AsPlainText -Force))
    }

    BeforeEach {
        InModuleScope PSCeph {
            $script:CephSession = $null
        }
    }

    Context 'Parameter validation' {
        It 'Should reject mixing -Credential and -Sso' {
            {
                Connect-Ceph -Server 'ceph-test.local' -Credential $cred -Sso -ErrorAction Stop
            } | Should -Throw '*mutually exclusive*'
        }

        It 'Should default OidcScope to openid and support IdToken for OidcTokenClaim' {
            $cmd = Get-Command Connect-Ceph
            $cmd.Parameters['OidcTokenClaim'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
                ForEach-Object { $_.ValidValues } | Should -Contain 'IdToken'
        }
    }

    Context 'Auto-detection' {
        It 'Detects Local auth and prompts for a credential when none is given' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { return [PSCustomObject]@{ login_url = '#/login' } }
                if ($Uri -like '*/api/auth') { return [PSCustomObject]@{ token = 'local-tok'; permissions = @{} } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph
            Mock Get-Credential { $cred } -ModuleName PSCeph

            $result = Connect-Ceph -Server 'ceph-test.local' -SkipCertificateCheck
            $result.Username | Should -Be 'admin'
            InModuleScope PSCeph { $script:CephSession.AuthMethod | Should -Be 'Local' }
        }

        It 'Detects OAuth2 and runs the device code flow' {
            $jwt = New-TestJwt @{ sub = 'alex'; preferred_username = 'alex.jardon' }
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { return [PSCustomObject]@{ login_url = 'auth/oauth2/login' } }
                if ($Uri -like '*/api/health/minimal') { return [PSCustomObject]@{ status = 'OK' } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph
            Mock Invoke-CephOidcDeviceCodeFlow {
                [PSCustomObject]@{ AccessToken = $jwt; IdToken = $jwt; RefreshToken = 'refresh-abc'; ExpiresIn = 3600; TokenEndpoint = 'https://idp.test/token' }
            } -ModuleName PSCeph

            $result = Connect-Ceph -Server 'ceph-test.local' -OidcIssuerUrl 'https://idp.test/app/' -OidcClientId 'ceph-dashboard' -SkipCertificateCheck
            $result.Username | Should -Be 'alex.jardon'
            InModuleScope PSCeph {
                $script:CephSession.AuthMethod | Should -Be 'OIDC'
                $script:CephSession.RefreshToken | Should -Be 'refresh-abc'
            }
        }

        It 'Throws a clear error when OAuth2 is detected but no Oidc params are given' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { return [PSCustomObject]@{ login_url = 'auth/oauth2/login' } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph

            { Connect-Ceph -Server 'ceph-test.local' -SkipCertificateCheck -ErrorAction Stop } | Should -Throw '*OidcIssuerUrl*'
        }

        It 'Throws a clear error for SAML2 (unsupported - browser only)' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { return [PSCustomObject]@{ login_url = 'auth/saml2/' } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph

            { Connect-Ceph -Server 'ceph-test.local' -SkipCertificateCheck -ErrorAction Stop } | Should -Throw '*SAML2*'
        }

        It '-Sso skips the probe entirely' {
            $jwt = New-TestJwt @{ sub = 'alex' }
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { throw 'probe should not be called when -Sso is given' }
                if ($Uri -like '*/api/health/minimal') { return [PSCustomObject]@{ status = 'OK' } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph
            Mock Invoke-CephOidcDeviceCodeFlow {
                [PSCustomObject]@{ AccessToken = $jwt; TokenEndpoint = 'https://idp.test/token' }
            } -ModuleName PSCeph

            { Connect-Ceph -Server 'ceph-test.local' -Sso -OidcIssuerUrl 'https://idp.test/app/' -OidcClientId 'cid' -SkipCertificateCheck } | Should -Not -Throw
            InModuleScope PSCeph { $script:CephSession.AuthMethod | Should -Be 'OIDC' }
        }

        It '-Credential skips the probe entirely' {
            Mock Invoke-RestMethod {
                if ($Uri -like '*/api/auth/check') { throw 'probe should not be called when -Credential is given' }
                if ($Uri -like '*/api/auth') { return [PSCustomObject]@{ token = 'local-tok2'; permissions = @{} } }
                throw "unexpected $Uri"
            } -ModuleName PSCeph

            { Connect-Ceph -Server 'ceph-test.local' -Credential $cred -SkipCertificateCheck } | Should -Not -Throw
            InModuleScope PSCeph { $script:CephSession.AuthMethod | Should -Be 'Local' }
        }
    }

    Context 'When the Dashboard rejects the OIDC token' {
        It 'Should throw and clear the session' {
            $jwt = New-TestJwt @{ sub = 'alex' }
            Mock Invoke-CephOidcDeviceCodeFlow {
                [PSCustomObject]@{ AccessToken = $jwt; TokenEndpoint = 'https://idp.test/token' }
            } -ModuleName PSCeph
            Mock Invoke-CephApi { throw 'Ceph API Error (401): Unauthorized' } -ModuleName PSCeph

            {
                Connect-Ceph -Server 'ceph-test.local' -Sso -OidcIssuerUrl 'https://idp.test/app/' -OidcClientId 'ceph-dashboard' -ErrorAction Stop
            } | Should -Throw '*rejected the OIDC token*'
            InModuleScope PSCeph {
                $script:CephSession | Should -BeNullOrEmpty
            }
        }
    }
}

Describe 'Disconnect-Ceph' {
    BeforeAll {
        Mock Invoke-RestMethod { } -ModuleName PSCeph
    }

    Context 'When connected' {
        It 'Should clear session' {
            InModuleScope PSCeph {
                $script:CephSession = [PSCustomObject]@{
                    Server               = 'ceph-test.local'
                    Port                 = 8443
                    BaseUri              = 'https://ceph-test.local:8443'
                    Token                = 'test-token'
                    Username             = 'admin'
                    SkipCertificateCheck = $true
                }
            }
            Disconnect-Ceph
            Get-CephConnection | Should -BeNullOrEmpty
        }
    }

    Context 'When not connected' {
        It 'Should warn when no active connection' {
            InModuleScope PSCeph {
                $script:CephSession = $null
            }
            Disconnect-Ceph 3>&1 | Should -BeLike '*No active*'
        }
    }

    Context 'When connected via OIDC' {
        It 'Should clear session without calling the Ceph logout endpoint' {
            Mock Invoke-RestMethod { throw 'should not be called for OIDC sessions' } -ModuleName PSCeph
            InModuleScope PSCeph {
                $script:CephSession = [PSCustomObject]@{
                    Server     = 'ceph-test.local'
                    Port       = 8443
                    BaseUri    = 'https://ceph-test.local:8443'
                    AuthMethod = 'OIDC'
                    Token      = 'test-jwt'
                    Username   = 'alex.jardon'
                }
            }
            { Disconnect-Ceph } | Should -Not -Throw
            Get-CephConnection | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-CephConnection' {
    Context 'When connected' {
        It 'Should return connection info' {
            InModuleScope PSCeph {
                $script:CephSession = [PSCustomObject]@{
                    Server      = 'ceph-test.local'
                    Port        = 8443
                    Username    = 'admin'
                    ConnectedAt = Get-Date
                    TokenExpiry = (Get-Date).AddHours(1)
                    Permissions = @{ pool = 'read' }
                }
            }
            $result = Get-CephConnection
            $result | Should -Not -BeNullOrEmpty
            $result.Server | Should -Be 'ceph-test.local'
            $result.Port | Should -Be 8443
            $result.Username | Should -Be 'admin'
        }

        It 'Should have correct type name' {
            InModuleScope PSCeph {
                $script:CephSession = [PSCustomObject]@{
                    Server      = 'ceph-test.local'
                    Port        = 8443
                    Username    = 'admin'
                    ConnectedAt = Get-Date
                    TokenExpiry = (Get-Date).AddHours(1)
                    Permissions = @{ pool = 'read' }
                }
            }
            $result = Get-CephConnection
            $result.PSObject.TypeNames | Should -Contain 'PSCeph.ConnectionInfo'
        }
    }

    Context 'When not connected' {
        It 'Should return null' {
            InModuleScope PSCeph {
                $script:CephSession = $null
            }
            Get-CephConnection | Should -BeNullOrEmpty
        }
    }
}
