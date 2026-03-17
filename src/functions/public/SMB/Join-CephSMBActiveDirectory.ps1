function Join-CephSMBActiveDirectory {
    <#
    .SYNOPSIS
        Joins an SMB cluster to Active Directory

    .DESCRIPTION
        Joins or re-joins a Ceph SMB cluster to an Active Directory
        domain for AD-based authentication.

    .PARAMETER ClusterId
        The ID of the SMB cluster to join.

    .PARAMETER DomainRealm
        The Active Directory domain realm (e.g., 'CORP.LOCAL').

    .PARAMETER Credential
        Credentials with permission to join the domain.

    .EXAMPLE
        Join-CephSMBActiveDirectory -ClusterId 'smb1' -DomainRealm 'CORP.LOCAL' -Credential (Get-Credential)
        Joins the SMB cluster to the specified domain.

    .EXAMPLE
        $cred = Get-Credential
        Get-CephSMBCluster | Where-Object AuthMode -eq 'active-directory' | Join-CephSMBActiveDirectory -DomainRealm 'CORP.LOCAL' -Credential $cred
        Re-joins all AD-configured clusters.

    .OUTPUTS
        PSCustomObject representing the joined cluster.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter(Mandatory)]
        [string]$DomainRealm,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    process {
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)

        $body = @{
            cluster_id      = $ClusterId
            auth_mode       = 'active-directory'
            domain_settings = @{
                realm        = $DomainRealm
                join_sources = @(
                    @{
                        source_type = 'password'
                        username    = $Credential.UserName
                        password    = $password
                    }
                )
            }
        }

        if ($PSCmdlet.ShouldProcess($ClusterId, "Join to Active Directory domain $DomainRealm")) {
            Invoke-CephApi -Endpoint "/api/smb/cluster/$ClusterId/join_auth" -Method PUT -Body $body

            Get-CephSMBCluster -ClusterId $ClusterId
        }
    }
}
