function Get-CephHost {
    <#
    .SYNOPSIS
        Gets information about hosts in the Ceph cluster

    .DESCRIPTION
        Retrieves information about all hosts or a specific host in the
        Ceph cluster, including services, labels, and status.

    .PARAMETER Hostname
        The hostname to retrieve. If not specified, returns all hosts.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephHost
        Returns all hosts in the cluster.

    .EXAMPLE
        Get-CephHost -Hostname 'ceph-node1'
        Returns information for a specific host.

    .EXAMPLE
        Get-CephHost | Where-Object { $_.Labels -contains 'osd' }
        Returns all hosts with the 'osd' label.

    .OUTPUTS
        PSCustomObject[] representing cluster hosts.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Hostname,

        [Parameter()]
        [switch]$Raw
    )

    process {
        if ($Hostname) {
            $response = Invoke-CephApi -Endpoint "/api/host/$Hostname"
            if ($Raw) {
                return $response
            }
            [PSCustomObject]@{
                PSTypeName = 'PSCeph.Host'
                Hostname   = $response.hostname
                Services   = $response.services
                Labels     = $response.labels
                Status     = $response.status
                Address    = $response.addr
                Sources    = $response.sources
            }
        }
        else {
            $response = Invoke-CephApi -Endpoint '/api/host'
            if ($Raw) {
                return $response
            }
            foreach ($hostEntry in $response) {
                [PSCustomObject]@{
                    PSTypeName = 'PSCeph.Host'
                    Hostname   = $hostEntry.hostname
                    Services   = $hostEntry.services
                    Labels     = $hostEntry.labels
                    Status     = $hostEntry.status
                    Address    = $hostEntry.addr
                    Sources    = $hostEntry.sources
                }
            }
        }
    }
}
