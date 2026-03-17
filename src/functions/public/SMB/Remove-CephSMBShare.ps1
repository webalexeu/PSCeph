function Remove-CephSMBShare {
    <#
    .SYNOPSIS
        Removes a Ceph SMB share.

    .DESCRIPTION
        Deletes an SMB share from a Ceph SMB cluster.
        The underlying CephFS data is not deleted.

    .PARAMETER ClusterId
        The ID of the SMB cluster containing the share.

    .PARAMETER ShareName
        The name of the share to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-CephSMBShare -ClusterId 'smb1' -ShareName 'data'
        Removes the specified share.

    .EXAMPLE
        Get-CephSMBShare -ClusterId 'smb1' | Where-Object Name -like 'temp*' | Remove-CephSMBShare -Force
        Removes all temporary shares.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ShareName,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess("$ClusterId/$ShareName", 'Remove SMB share')) {
            Invoke-CephApi -Endpoint "/api/smb/share/$ClusterId/$ShareName" -Method DELETE
            Write-Verbose "SMB share '$ShareName' removed from cluster '$ClusterId'."
        }
    }
}
