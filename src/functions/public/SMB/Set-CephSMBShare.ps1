function Set-CephSMBShare {
    <#
    .SYNOPSIS
        Modifies a Ceph SMB share.

    .DESCRIPTION
        Updates properties of an existing SMB share such as
        read-only status or browseable flag.

    .PARAMETER ClusterId
        The ID of the SMB cluster containing the share.

    .PARAMETER ShareName
        The name of the share to modify.

    .PARAMETER ReadOnly
        Set read-only status.

    .PARAMETER Browsable
        Set browseable status.

    .PARAMETER Path
        Update the CephFS path.

    .EXAMPLE
        Set-CephSMBShare -ClusterId 'smb1' -ShareName 'data' -ReadOnly $true
        Makes the share read-only.

    .EXAMPLE
        Set-CephSMBShare -ClusterId 'smb1' -ShareName 'hidden' -Browsable $false
        Hides the share from browse lists.

    .OUTPUTS
        PSCustomObject representing the modified share.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$ClusterId,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]$ShareName,

        [Parameter()]
        [bool]$ReadOnly,

        [Parameter()]
        [bool]$Browsable,

        [Parameter()]
        [string]$Path
    )

    process {
        $body = @{
            cluster_id = $ClusterId
            share_id   = $ShareName
        }

        if ($PSBoundParameters.ContainsKey('ReadOnly')) { $body['readonly'] = $ReadOnly }
        if ($PSBoundParameters.ContainsKey('Browsable')) { $body['browseable'] = $Browsable }
        if ($Path) { $body['cephfs'] = @{ path = $Path } }

        if ($PSCmdlet.ShouldProcess("$ClusterId/$ShareName", 'Modify SMB share')) {
            Invoke-CephApi -Endpoint "/api/smb/share/$ClusterId/$ShareName" -Method PUT -Body $body

            Get-CephSMBShare -ClusterId $ClusterId -ShareName $ShareName
        }
    }
}
