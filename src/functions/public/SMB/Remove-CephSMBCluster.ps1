function Remove-CephSMBCluster {
    <#
    .SYNOPSIS
        Removes a Ceph SMB cluster

    .DESCRIPTION
        Deletes an SMB cluster and all associated shares from Ceph.

    .PARAMETER ClusterId
        The ID of the SMB cluster to remove.

    .PARAMETER Force
        Force removal without confirmation.

    .EXAMPLE
        Remove-CephSMBCluster -ClusterId 'smb1'
        Removes the specified SMB cluster.

    .EXAMPLE
        Get-CephSMBCluster | Where-Object ShareCount -eq 0 | Remove-CephSMBCluster -Force
        Removes all empty SMB clusters.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id', 'Name')]
        [string]$ClusterId,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess($ClusterId, 'Remove SMB cluster')) {
            Invoke-CephApi -Endpoint "/api/smb/cluster/$ClusterId" -Method DELETE
            Write-Verbose "SMB cluster '$ClusterId' has been removed."
        }
    }
}
