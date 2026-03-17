function Remove-CephPool {
    <#
    .SYNOPSIS
        Removes a Ceph storage pool

    .DESCRIPTION
        Deletes a storage pool from the Ceph cluster. This operation is
        destructive and will permanently delete all data in the pool.

    .PARAMETER Name
        The name of the pool to remove.

    .PARAMETER Force
        Bypass confirmation prompt. Use with caution.

    .EXAMPLE
        Remove-CephPool -Name 'mypool'
        Removes the specified pool after confirmation.

    .EXAMPLE
        Remove-CephPool -Name 'mypool' -Force
        Removes the pool without confirmation.

    .EXAMPLE
        Get-CephPool -Name 'temp-*' | Remove-CephPool
        Removes all pools matching the pattern.

    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('PoolName')]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    process {
        if ($Force) {
            $ConfirmPreference = 'None'
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Remove Ceph pool (DATA WILL BE PERMANENTLY DELETED)')) {
            Invoke-CephApi -Endpoint "/api/pool/$Name" -Method DELETE
            Write-Verbose "Pool '$Name' has been removed."
        }
    }
}
