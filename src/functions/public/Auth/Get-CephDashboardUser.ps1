function Get-CephDashboardUser {
    <#
    .SYNOPSIS
        Gets Ceph Dashboard users

    .DESCRIPTION
        Retrieves information about Ceph Dashboard web interface users,
        including their roles and permissions.

    .PARAMETER Username
        The username of a specific dashboard user to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephDashboardUser
        Returns all dashboard users.

    .EXAMPLE
        Get-CephDashboardUser -Username 'admin'
        Returns the admin dashboard user.

    .EXAMPLE
        Get-CephDashboardUser | Where-Object { 'administrator' -in $_.Roles }
        Returns users with administrator role.

    .OUTPUTS
        PSCustomObject[] representing Dashboard users.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$Username,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($Username) {
            $response = Invoke-CephApi -Endpoint "/api/user/$Username"
            if ($Raw) {
                return $response
            }
            [PSCustomObject]@{
                PSTypeName        = 'PSCeph.DashboardUser'
                Username          = $response.username
                Name              = $response.name
                Email             = $response.email
                Roles             = $response.roles
                LastUpdate        = $response.last_update
                Enabled           = $response.enabled
                PwdExpDate        = $response.pwd_expiration_date
                PwdUpdateRequired = $response.pwd_update_required
            }
        }
        else {
            $response = Invoke-CephApi -Endpoint '/api/user'
            if ($Raw) {
                return $response
            }
            foreach ($user in $response) {
                [PSCustomObject]@{
                    PSTypeName        = 'PSCeph.DashboardUser'
                    Username          = $user.username
                    Name              = $user.name
                    Email             = $user.email
                    Roles             = $user.roles
                    LastUpdate        = $user.last_update
                    Enabled           = $user.enabled
                    PwdExpDate        = $user.pwd_expiration_date
                    PwdUpdateRequired = $user.pwd_update_required
                }
            }
        }
    }
}
