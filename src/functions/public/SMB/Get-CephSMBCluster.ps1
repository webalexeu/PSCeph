function Get-CephSMBCluster {
    <#
    .SYNOPSIS
        Gets Ceph SMB clusters

    .DESCRIPTION
        Retrieves information about SMB clusters in Ceph, including
        cluster configuration and authentication settings.

    .PARAMETER ClusterId
        The ID of a specific SMB cluster to retrieve.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephSMBCluster
        Returns all SMB clusters.

    .EXAMPLE
        Get-CephSMBCluster -ClusterId 'smb1'
        Returns a specific SMB cluster.

    .OUTPUTS
        PSCustomObject[] representing SMB clusters.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id', 'Name')]
        [string]$ClusterId,

        [Parameter()]
        [switch]$Raw
    )

    process {
        $response = Invoke-CephApi -Endpoint '/api/smb/cluster'

        if ($Raw) {
            if ($ClusterId) {
                return $response | Where-Object { $_.cluster_id -eq $ClusterId }
            }
            return $response
        }

        $clusters = foreach ($cluster in $response) {
            [PSCustomObject]@{
                PSTypeName        = 'PSCeph.SMBCluster'
                ClusterId         = $cluster.cluster_id
                AuthMode          = $cluster.auth_mode
                DomainSettings    = $cluster.domain_settings
                UserGroupSettings = $cluster.user_group_settings
                CustomDNS         = $cluster.custom_dns
                Placement         = $cluster.placement
                ClusteringEnabled = $cluster.clustering
                ShareCount        = ($cluster.shares | Measure-Object).Count
            }
        }

        if ($ClusterId) {
            $clusters | Where-Object { $_.ClusterId -eq $ClusterId }
        }
        else {
            $clusters
        }
    }
}
