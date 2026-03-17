function New-CephSMBCluster {
    <#
    .SYNOPSIS
        Creates a new Ceph SMB cluster

    .DESCRIPTION
        Creates a new SMB cluster for serving CephFS shares via SMB/CIFS
        protocol with specified authentication mode.

    .PARAMETER ClusterId
        The unique identifier for the SMB cluster.

    .PARAMETER AuthMode
        Authentication mode: 'user' for local users or 'active-directory'.

    .PARAMETER DomainRealm
        Active Directory domain realm (required for AD auth).

    .PARAMETER DomainJoinUser
        Domain admin username for joining AD.

    .PARAMETER DomainJoinPassword
        Domain admin password for joining AD.

    .PARAMETER Placement
        Placement specification for the SMB service.

    .PARAMETER Clustering
        Enable SMB clustering (CTDB).

    .EXAMPLE
        New-CephSMBCluster -ClusterId 'smb1' -AuthMode user
        Creates an SMB cluster with local user authentication.

    .EXAMPLE
        New-CephSMBCluster -ClusterId 'smb1' -AuthMode 'active-directory' -DomainRealm 'CORP.LOCAL'
        Creates an SMB cluster joined to Active Directory.

    .OUTPUTS
        PSCustomObject representing the created SMB cluster.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [Alias('Id', 'Name')]
        [string]$ClusterId,

        [Parameter(Mandatory)]
        [ValidateSet('user', 'active-directory')]
        [string]$AuthMode,

        [Parameter()]
        [string]$DomainRealm,

        [Parameter()]
        [string]$DomainJoinUser,

        [Parameter()]
        [securestring]$DomainJoinPassword,

        [Parameter()]
        [string]$Placement,

        [Parameter()]
        [switch]$Clustering
    )

    if ($AuthMode -eq 'active-directory' -and -not $DomainRealm) {
        throw 'DomainRealm is required for Active Directory authentication.'
    }

    $body = @{
        cluster_id = $ClusterId
        auth_mode  = $AuthMode
    }

    if ($AuthMode -eq 'active-directory') {
        $body['domain_settings'] = @{
            realm = $DomainRealm
        }
        if ($DomainJoinUser) {
            $body['domain_settings']['join_sources'] = @(
                @{
                    source_type = 'password'
                    username    = $DomainJoinUser
                }
            )
            if ($DomainJoinPassword) {
                $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($DomainJoinPassword)
                $body['domain_settings']['join_sources'][0]['password'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
                [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
    }

    if ($Placement) {
        $body['placement'] = $Placement
    }
    if ($Clustering) {
        $body['clustering'] = 'default'
    }

    if ($PSCmdlet.ShouldProcess($ClusterId, 'Create SMB cluster')) {
        Invoke-CephApi -Endpoint '/api/smb/cluster' -Method POST -Body $body

        Get-CephSMBCluster -ClusterId $ClusterId
    }
}
