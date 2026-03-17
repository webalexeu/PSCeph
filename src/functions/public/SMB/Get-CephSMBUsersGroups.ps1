function Get-CephSMBUsersGroups {
    <#
    .SYNOPSIS
        Gets SMB users and groups.

    .DESCRIPTION
        Retrieves local SMB users and groups configuration for
        an SMB cluster using local user authentication.

    .PARAMETER ClusterId
        The ID of the SMB cluster.

    .PARAMETER ResourceType
        Filter by resource type: 'users' or 'groups'.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephSMBUsersGroups -ClusterId 'smb1'
        Returns all users and groups for the cluster.

    .EXAMPLE
        Get-CephSMBUsersGroups -ClusterId 'smb1' -ResourceType users
        Returns only users.

    .EXAMPLE
        Get-CephSMBCluster | Get-CephSMBUsersGroups
        Returns users and groups for all clusters.

    .OUTPUTS
        PSCustomObject[] representing SMB users and groups.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter()]
        [ValidateSet('users', 'groups')]
        [string]$ResourceType,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint "/api/smb/usersgroups?cluster_id=$ClusterId"

        if ($Raw) {
            if ($ResourceType) {
                return $response | Where-Object { $_.resource_type -eq $ResourceType }
            }
            return $response
        }

        $results = foreach ($item in $response) {
            [PSCustomObject]@{
                PSTypeName   = 'PSCeph.SMBUserGroup'
                ClusterId    = $ClusterId
                ResourceType = $item.resource_type
                Name         = $item.name
                Values       = $item.values
            }
        }

        if ($ResourceType) {
            $results | Where-Object { $_.ResourceType -eq $ResourceType }
        }
        else {
            $results
        }
    }
}
