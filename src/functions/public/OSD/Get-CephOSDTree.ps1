function Get-CephOSDTree {
    <#
    .SYNOPSIS
        Gets the Ceph OSD tree (CRUSH map hierarchy)

    .DESCRIPTION
        Retrieves the hierarchical view of OSDs organized by CRUSH map
        structure including roots, datacenters, racks, hosts, and OSDs.

    .PARAMETER Raw
        Returns the raw API response object.

    .EXAMPLE
        Get-CephOSDTree
        Returns the full OSD tree structure.

    .EXAMPLE
        Get-CephOSDTree | Where-Object { $_.Type -eq 'host' }
        Returns only host-level entries in the tree.

    .EXAMPLE
        Get-CephOSDTree | Where-Object { $_.Type -eq 'osd' -and $_.Status -eq 'up' }
        Returns only OSDs that are up.

    .OUTPUTS
        PSCustomObject[] representing the OSD tree nodes.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$Raw
    )

    # Use /api/health/full which contains the OSD tree in osd_map.tree
    $response = Invoke-CephApi -Endpoint '/api/health/full'

    if (-not $response.osd_map.tree) {
        Write-Warning 'OSD tree data not available in API response'
        return
    }

    $treeData = $response.osd_map.tree

    if ($Raw) {
        return $treeData
    }

    # Process each node in the tree
    foreach ($node in $treeData.nodes) {
        [PSCustomObject]@{
            PSTypeName      = 'PSCeph.OSDTreeNode'
            Id              = $node.id
            Name            = $node.name
            Type            = $node.type
            TypeId          = $node.type_id
            CrushWeight     = $node.crush_weight
            DeviceClass     = $node.device_class
            Status          = $node.status
            Exists          = $node.exists
            Reweight        = $node.reweight
            PrimaryAffinity = $node.primary_affinity
            Depth           = $node.depth
            Children        = $node.children
        }
    }
}
