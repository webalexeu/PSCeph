function Connect-Ceph {
    <#
    .SYNOPSIS
        Establishes a connection to a Ceph Dashboard API.

    .DESCRIPTION
        Authenticates to the Ceph Dashboard REST API and stores the session token
        for subsequent API calls. The connection persists until Disconnect-Ceph
        is called or the PowerShell session ends.

    .PARAMETER Server
        The hostname or IP address of the Ceph Dashboard server.

    .PARAMETER Port
        The port number for the Ceph Dashboard. Defaults to 8443.

    .PARAMETER Credential
        PSCredential object containing the username and password for authentication.

    .PARAMETER SkipCertificateCheck
        Skip SSL certificate validation. Use with caution in production environments.

    .EXAMPLE
        Connect-Ceph -Server 'ceph-mgr.local' -Credential (Get-Credential)
        Connects to the Ceph Dashboard using interactive credential prompt.

    .EXAMPLE
        $cred = Get-Credential
        Connect-Ceph -Server '192.168.1.100' -Port 8443 -Credential $cred -SkipCertificateCheck
        Connects to a Ceph Dashboard with a self-signed certificate.

    .OUTPUTS
        PSCustomObject representing the connection information.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 8443,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [switch]$SkipCertificateCheck
    )

    $baseUri = "https://${Server}:${Port}"
    $authUri = "$baseUri/api/auth"

    Write-Verbose "Connecting to Ceph Dashboard at $baseUri"

    $authBody = @{
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    } | ConvertTo-Json -Compress

    $params = @{
        Uri         = $authUri
        Method      = 'POST'
        Body        = $authBody
        ContentType = 'application/json'
        Headers     = @{ Accept = 'application/vnd.ceph.api.v1.0+json' }
    }

    if ($SkipCertificateCheck) {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $params['SkipCertificateCheck'] = $true
        }
        else {
            # PowerShell 5.1 compatibility
            if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
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
            }
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        }
    }

    try {
        $response = Invoke-RestMethod @params
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            throw "Failed to connect to Ceph Dashboard at $baseUri. Status: $statusCode. Error: $errorMessage"
        }
        throw "Failed to connect to Ceph Dashboard at $baseUri. Error: $errorMessage"
    }

    if (-not $response.token) {
        throw 'Authentication succeeded but no token was returned.'
    }

    $script:CephSession = [PSCustomObject]@{
        PSTypeName           = 'PSCeph.Connection'
        Server               = $Server
        Port                 = $Port
        BaseUri              = $baseUri
        Token                = $response.token
        TokenExpiry          = (Get-Date).AddHours(1)
        Username             = $Credential.UserName
        SkipCertificateCheck = $SkipCertificateCheck.IsPresent
        ConnectedAt          = Get-Date
        Permissions          = $response.permissions
    }

    Write-Verbose "Successfully connected to Ceph Dashboard as $($Credential.UserName)"

    [PSCustomObject]@{
        PSTypeName  = 'PSCeph.ConnectionInfo'
        Server      = $Server
        Port        = $Port
        Username    = $Credential.UserName
        ConnectedAt = $script:CephSession.ConnectedAt
        Permissions = $response.permissions
    }
}
