function Get-CephUser {
    <#
    .SYNOPSIS
        Gets Ceph RADOS users (auth entities)

    .DESCRIPTION
        Retrieves information about Ceph authentication entities (users),
        including their capabilities and keys.

    .PARAMETER Name
        The name of a specific user to retrieve (e.g., 'client.admin').

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephUser
        Returns all Ceph users.

    .EXAMPLE
        Get-CephUser -Name 'client.admin'
        Returns the admin client user.

    .EXAMPLE
        Get-CephUser | Where-Object { $_.Caps.mon -like '*allow rwx*' }
        Returns users with specific monitor capabilities.

    .OUTPUTS
        PSCustomObject[] representing Ceph users.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Entity', 'Username')]
        [string]$Name,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint '/api/auth'

        if ($Raw) {
            if ($Name) {
                return $response | Where-Object { $_.entity -eq $Name -or $_.entity -eq "client.$Name" }
            }
            return $response
        }

        $users = foreach ($user in $response) {
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.User'
                Entity     = $user.entity
                Caps       = $user.caps
                Key        = $user.key
            }
        }

        if ($Name) {
            $users | Where-Object { $_.Entity -eq $Name -or $_.Entity -eq "client.$Name" }
        }
        else {
            $users
        }
    }
}
