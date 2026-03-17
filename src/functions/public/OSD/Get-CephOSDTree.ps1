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

    .OUTPUTS
        PSCustomObject[] representing the OSD tree nodes.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$Raw
    )

    $response = Invoke-CephApi -Endpoint '/api/osd/tree'

    if ($Raw) {
        return $response
    }

    $convertNode = {
        param($Node, $ParentId = $null, $Depth = 0)

        [PSCustomObject]@{
            PSTypeName      = 'PSCeph.OSDTreeNode'
            Id              = $Node.id
            Name            = $Node.name
            Type            = $Node.type
            TypeId          = $Node.type_id
            CrushWeight     = $Node.crush_weight
            Depth           = $Depth
            ParentId        = $ParentId
            DeviceClass     = $Node.device_class
            Status          = $Node.status
            Exists          = $Node.exists
            Reweight        = $Node.reweight
            PrimaryAffinity = $Node.primary_affinity
        }

        if ($Node.children) {
            foreach ($child in $Node.children) {
                & $convertNode -Node $child -ParentId $Node.id -Depth ($Depth + 1)
            }
        }
    }

    if ($response.nodes) {
        foreach ($rootNode in ($response.nodes | Where-Object { $_.type -eq 'root' })) {
            & $convertNode -Node $rootNode
        }
    }
    elseif ($response) {
        foreach ($node in $response) {
            [PSCustomObject]@{
                PSTypeName  = 'PSCeph.OSDTreeNode'
                Id          = $node.id
                Name        = $node.name
                Type        = $node.type
                TypeId      = $node.type_id
                CrushWeight = $node.crush_weight
                Status      = $node.status
                DeviceClass = $node.device_class
                Exists      = $node.exists
                Reweight    = $node.reweight
                Children    = $node.children
            }
        }
    }
}
