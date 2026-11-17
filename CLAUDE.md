# PSCeph Module Specifications

This document contains the specifications and implementation details for the PSCeph PowerShell module.

## Overview

PSCeph is a PowerShell module for managing Ceph clusters through the Ceph Dashboard REST API (ceph-mgr RESTful module).

## Module Structure

```
src/
├── functions/
│   ├── private/
│   │   ├── Invoke-CephApi.ps1           # Core API helper
│   │   ├── Resolve-CephAuthMethod.ps1   # Auto-detects Local vs OAuth2 vs SAML2
│   │   ├── Invoke-CephOidcDeviceCodeFlow.ps1  # RFC 8628 device code grant
│   │   └── ConvertFrom-JwtPayload.ps1   # Decode JWT claims (no signature check)
│   └── public/
│       ├── Connection/
│       │   ├── Connect-Ceph.ps1
│       │   ├── Disconnect-Ceph.ps1
│       │   └── Get-CephConnection.ps1
│       ├── Cluster/
│       │   ├── Get-CephHealth.ps1
│       │   ├── Get-CephStatus.ps1
│       │   ├── Get-CephConfig.ps1
│       │   ├── Get-CephHost.ps1
│       │   ├── Get-CephHostDevice.ps1
│       │   └── Get-CephHostDaemon.ps1
│       ├── Pool/
│       │   ├── Get-CephPool.ps1
│       │   ├── New-CephPool.ps1
│       │   ├── Set-CephPool.ps1
│       │   └── Remove-CephPool.ps1
│       ├── OSD/
│       │   ├── Get-CephOSD.ps1
│       │   ├── Set-CephOSD.ps1
│       │   └── Get-CephOSDTree.ps1
│       ├── Monitor/
│       │   └── Get-CephMonitor.ps1
│       ├── RBD/
│       │   ├── Get-CephRBDImage.ps1
│       │   ├── New-CephRBDImage.ps1
│       │   ├── Remove-CephRBDImage.ps1
│       │   ├── Get-CephRBDSnapshot.ps1
│       │   └── New-CephRBDSnapshot.ps1
│       ├── CephFS/
│       │   ├── Get-CephFS.ps1
│       │   └── Get-CephFSDirectory.ps1
│       ├── Auth/
│       │   ├── Get-CephUser.ps1
│       │   └── Get-CephDashboardUser.ps1
│       ├── NVMeoF/
│       │   ├── Get-CephNVMeoFGateway.ps1
│       │   ├── Get-CephNVMeoFSubsystem.ps1
│       │   ├── New-CephNVMeoFSubsystem.ps1
│       │   ├── Remove-CephNVMeoFSubsystem.ps1
│       │   ├── Get-CephNVMeoFNamespace.ps1
│       │   ├── New-CephNVMeoFNamespace.ps1
│       │   ├── Remove-CephNVMeoFNamespace.ps1
│       │   ├── Get-CephNVMeoFHost.ps1
│       │   ├── Add-CephNVMeoFHost.ps1
│       │   └── Remove-CephNVMeoFHost.ps1
│       └── SMB/
│           ├── Get-CephSMBCluster.ps1
│           ├── New-CephSMBCluster.ps1
│           ├── Remove-CephSMBCluster.ps1
│           ├── Get-CephSMBShare.ps1
│           ├── New-CephSMBShare.ps1
│           ├── Set-CephSMBShare.ps1
│           ├── Remove-CephSMBShare.ps1
│           ├── Get-CephSMBUsersGroups.ps1
│           └── Join-CephSMBActiveDirectory.ps1
├── variables/
│   └── private/
│       └── CephSession.ps1              # Session storage variable
└── classes/
    └── public/
        └── (reserved for future use)
```

## Ceph Dashboard API Specifications

### Authentication

- **Endpoint**: `POST /api/auth`
- **Body**: `{"username": "...", "password": "..."}`
- **Response**: `{"token": "...", "permissions": {...}}`
- **Token Expiry**: 1 hour (refresh at 55 minutes)
- **Refresh Endpoint**: `POST /api/auth/refresh`

### OIDC Authentication (Device Code Grant) and Auth Method Auto-Detection

`Connect-Ceph` supports two authentication methods - local (username/password)
and the OIDC device code grant (RFC 8628) for clusters with
`ceph dashboard sso enable oauth2` configured - and normally picks the right
one itself instead of requiring the caller to specify it.

**Auto-detection:** `Resolve-CephAuthMethod.ps1` calls the Dashboard's own
*unauthenticated* `POST /api/auth/check` (no token supplied) and inspects the
returned `login_url`. Ceph's backend sets this to a protocol-specific,
hardcoded value (see `services/auth/{auth,oauth2,saml2}.py`'s `LOGIN_URL`
class attributes):
- `'#/login'` -> Local auth
- `'auth/oauth2/login'` -> OAuth2 SSO -> run the device code flow
- `'auth/saml2/...'` -> SAML2 SSO -> throw (browser-only, unsupported here)

`Connect-Ceph` only skips this probe when the caller is explicit about which
method to use: passing `-Credential` forces local auth, and `-Sso` forces the
OIDC flow. Passing both is a parameter error. The common case -
`Connect-Ceph -Server x` with nothing else - always goes through the probe.

**OIDC specifics:** nothing in `Invoke-CephOidcDeviceCodeFlow.ps1` is
provider-specific - it discovers `device_authorization_endpoint` and
`token_endpoint` via `{IssuerUrl}/.well-known/openid-configuration`, so it
works against authentik, Keycloak, Okta, Entra ID, or any other RFC
8628-compliant provider. Ceph has no API to expose the issuer URL/client ID
it expects, though, so `-OidcIssuerUrl`/`-OidcClientId` must still be supplied
by the caller whenever the OIDC path is taken (auto-detected or forced via
`-Sso`) - `Connect-Ceph` throws a clear error naming both if they're missing.

**Important: the Ceph Dashboard does not verify JWT signatures in OAuth2 SSO
mode.** Its backend (`services/auth/oauth2.py`) reads a JWT from either the
`token` cookie or an `X-Access-Token` header and trusts the claims (`sub`,
`jti`, roles) without checking a signature, issuer, or JWKS. This is Ceph's
own behavior, not a weakness introduced by this module - PSCeph just needs a
real JWT from the configured IdP and sends it in `X-Access-Token`.

Flow once the OIDC path is taken:
1. `Invoke-CephOidcDeviceCodeFlow` requests a device code, prints the
   verification URL/code, then polls the token endpoint (honoring
   `authorization_pending`/`slow_down` per RFC 8628) until the user approves.
2. `Connect-Ceph` picks either the `access_token` or `id_token` (via
   `-OidcTokenClaim`, default `AccessToken` - whichever one carries the role
   claims your `ceph dashboard sso enable oauth2 --roles_path` expects),
   decodes it with `ConvertFrom-JwtPayload` just to show the authenticated
   identity (`preferred_username`/`sub`), and stores it as `$script:CephSession.Token`.
3. A connectivity check (`GET /api/health/minimal`) confirms the Dashboard
   actually accepts the token before `Connect-Ceph` returns successfully.
4. `Invoke-CephApi` sends `X-Access-Token: <token>` instead of
   `Authorization: Bearer <token>` when `$session.AuthMethod -eq 'OIDC'`, and
   refreshes via the IdP's `token_endpoint` (`grant_type=refresh_token`)
   instead of Ceph's own `/api/auth/refresh`. If no refresh token was issued
   (e.g. provider didn't grant `offline_access`), it warns to reconnect.
5. `Disconnect-Ceph` skips the `/api/auth/logout` call for OIDC sessions -
   there's no Dashboard-side session to invalidate, only the local token.

### API Versioning

The Ceph Dashboard API uses content negotiation with Accept headers:

```
Accept: application/vnd.ceph.api.v1.0+json   # Most endpoints
Accept: application/vnd.ceph.api.v2.0+json   # Block, NVMeoF, SMB, RGW endpoints
```

**Version Detection by Endpoint:**
- v2.0 endpoints: `/api/block/*`, `/api/nvmeof/*`, `/api/smb/*`, `/api/rgw/*`
- v1.0 endpoints: All other endpoints

### Key API Endpoints

| Category | Endpoint                                     | Method         | Description          |
|----------|----------------------------------------------|----------------|----------------------|
| Auth     | `/api/auth`                                  | POST           | Authenticate         |
| Auth     | `/api/auth/refresh`                          | POST           | Refresh token        |
| Health   | `/api/health/minimal`                        | GET            | Basic health         |
| Health   | `/api/health/full`                           | GET            | Detailed health      |
| Cluster  | `/api/cluster`                               | GET            | Cluster status       |
| Config   | `/api/cluster_conf`                          | GET            | Configuration        |
| Hosts    | `/api/host`                                  | GET            | List hosts           |
| Hosts    | `/api/host/{hostname}`                       | GET            | Host details         |
| Hosts    | `/api/host/{hostname}/devices`               | GET            | Host devices         |
| Hosts    | `/api/host/{hostname}/daemons`               | GET            | Host daemons         |
| Pools    | `/api/pool`                                  | GET/POST       | List/create pools    |
| Pools    | `/api/pool/{name}`                           | GET/PUT/DELETE | Pool operations      |
| OSDs     | `/api/osd`                                   | GET            | List OSDs            |
| OSDs     | `/api/osd/{id}`                              | GET/PUT        | OSD operations       |
| OSDs     | `/api/osd/tree`                              | GET            | OSD tree             |
| Monitors | `/api/monitor`                               | GET            | List monitors        |
| RBD      | `/api/block/image`                           | GET            | List images (v2.0)   |
| RBD      | `/api/block/image/{pool}/{namespace}/{image}`| GET/POST/DELETE| Image operations     |
| CephFS   | `/api/cephfs`                                | GET            | List filesystems     |
| CephFS   | `/api/cephfs/{name}`                         | GET            | Filesystem details   |
| CephFS   | `/api/cephfs/{name}/ls_dir`                  | GET            | List directory       |
| Auth     | `/api/auth`                                  | GET            | List RADOS users     |
| Users    | `/api/user`                                  | GET            | List dashboard users |
| NVMeoF   | `/api/nvmeof/gateway`                        | GET            | List gateways (v2.0) |
| NVMeoF   | `/api/nvmeof/subsystem`                      | GET/POST       | Subsystems (v2.0)    |
| NVMeoF   | `/api/nvmeof/subsystem/{nqn}/namespace`      | GET/POST       | Namespaces           |
| NVMeoF   | `/api/nvmeof/subsystem/{nqn}/host`           | GET/POST       | Hosts                |
| SMB      | `/api/smb/cluster`                           | GET/POST       | SMB clusters (v2.0)  |
| SMB      | `/api/smb/share`                             | GET/POST       | SMB shares           |
| SMB      | `/api/smb/usersgroups`                       | GET            | Users/groups         |

### Response Handling

**v2.0 API Response Format:**
```json
{
  "value": [...],
  "pool_name": "..."
}
```
The actual data is wrapped in a `value` property.

**Pagination (RBD Images):**
- `?limit=N` - Maximum results (default: 100)
- `?offset=N` - Skip N results

## Implementation Patterns

### Connection Session

Store connection state in `$script:CephSession`:

```powershell
$script:CephSession = [PSCustomObject]@{
    PSTypeName           = 'PSCeph.Connection'
    Server               = $Server
    Port                 = $Port
    BaseUri              = "https://${Server}:${Port}"
    Token                = $response.token
    TokenExpiry          = (Get-Date).AddHours(1)
    Username             = $Credential.UserName
    SkipCertificateCheck = $SkipCertificateCheck.IsPresent
    ConnectedAt          = Get-Date
    Permissions          = $response.permissions
}
```

### Cmdlet Output

All Get-* cmdlets support `-Raw` switch:
- Default: Return PSCustomObjects with typed properties and PSTypeName
- With `-Raw`: Return raw API response

```powershell
if ($Raw) {
    return $response
}

[PSCustomObject]@{
    PSTypeName = 'PSCeph.TypeName'
    Property1  = $response.property1
    Property2  = $response.property2
}
```

### Error Handling

Parse API error responses:

```powershell
catch {
    $statusCode = [int]$_.Exception.Response.StatusCode
    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $responseBody = $reader.ReadToEnd()
    $errorDetail = $responseBody | ConvertFrom-Json -ErrorAction SilentlyContinue
    $errorMessage = $errorDetail.detail ?? $errorDetail.message ?? $_.Exception.Message

    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
        [System.Exception]::new("Ceph API Error ($statusCode): $errorMessage"),
        'CephApiError',
        [System.Management.Automation.ErrorCategory]::InvalidOperation,
        $uri
    ))
}
```

### PowerShell Version Compatibility

Support PS 5.1, PS 7, and PS Core:

```powershell
# SkipCertificateCheck only available in PS 6+
if ($SkipCertificateCheck -and $PSVersionTable.PSVersion.Major -ge 6) {
    $params['SkipCertificateCheck'] = $true
}
else {
    # PowerShell 5.1 fallback
    Add-Type -TypeDefinition @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
```

### Destructive Operations

Use ShouldProcess and ConfirmImpact:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [switch]$Force
)

if ($Force) {
    $ConfirmPreference = 'None'
}

if ($PSCmdlet.ShouldProcess($Name, 'Remove')) {
    Invoke-CephApi -Endpoint "/api/pool/$Name" -Method DELETE
}
```

## PSTypeName Conventions

| Type            | PSTypeName             |
|-----------------|------------------------|
| Connection      | PSCeph.Connection      |
| ConnectionInfo  | PSCeph.ConnectionInfo  |
| Health          | PSCeph.Health          |
| HealthFull      | PSCeph.HealthFull      |
| ClusterStatus   | PSCeph.ClusterStatus   |
| Config          | PSCeph.Config          |
| Host            | PSCeph.Host            |
| HostDevice      | PSCeph.HostDevice      |
| HostDaemon      | PSCeph.HostDaemon      |
| Pool            | PSCeph.Pool            |
| OSD             | PSCeph.OSD             |
| OSDTreeNode     | PSCeph.OSDTreeNode     |
| Monitor         | PSCeph.Monitor         |
| RBDImage        | PSCeph.RBDImage        |
| RBDSnapshot     | PSCeph.RBDSnapshot     |
| CephFS          | PSCeph.CephFS          |
| CephFSDirectory | PSCeph.CephFSDirectory |
| User            | PSCeph.User            |
| DashboardUser   | PSCeph.DashboardUser   |
| NVMeoFGateway   | PSCeph.NVMeoFGateway   |
| NVMeoFSubsystem | PSCeph.NVMeoFSubsystem |
| NVMeoFNamespace | PSCeph.NVMeoFNamespace |
| NVMeoFHost      | PSCeph.NVMeoFHost      |
| SMBCluster      | PSCeph.SMBCluster      |
| SMBShare        | PSCeph.SMBShare        |
| SMBUserGroup    | PSCeph.SMBUserGroup    |

## Testing

Tests use Pester with mocked API responses:

```powershell
BeforeAll {
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

Describe 'Get-CephPool' {
    BeforeAll {
        Mock Invoke-CephApi {
            @(@{ pool_name = 'rbd'; pool = 1; type = 'replicated' })
        }
    }

    It 'Should return pools' {
        $result = Get-CephPool
        $result | Should -Not -BeNullOrEmpty
    }
}
```

## PSScriptAnalyzer Compliance

- Use approved verbs only
- Avoid `$host` variable (shadows built-in) - use `$hostEntry` instead
- Include ShouldProcess for state-changing operations
- Use `[CmdletBinding()]` attribute
- Include proper help documentation

## Ceph Version Compatibility

The module is designed to work with:
- Ceph Luminous (12.x) and later
- Ceph Tentacle (latest) with v2.0 API endpoints
- Automatic API version detection based on endpoint path
