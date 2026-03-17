<#
    .SYNOPSIS
    General examples of how to use the PSCeph module.

    .DESCRIPTION
    This script demonstrates common operations with the PSCeph module
    for managing Ceph clusters through the Dashboard API.
#>

# Import the module
Import-Module -Name 'PSCeph'

#region Connection Management

# Connect to a Ceph cluster (will prompt for credentials)
Connect-Ceph -Server 'ceph-mgr.example.com' -Port 8443

# Connect with stored credentials
$credential = Get-Credential -UserName 'admin'
Connect-Ceph -Server 'ceph-mgr.example.com' -Credential $credential

# Connect and skip certificate validation (for self-signed certs)
Connect-Ceph -Server 'ceph-mgr.example.com' -Credential $credential -SkipCertificateCheck

# Check current connection status
Get-CephConnection

# Disconnect when done
Disconnect-Ceph

#endregion

#region Cluster Health and Status

# Get quick cluster health status
Get-CephHealth

# Get detailed health information
Get-CephHealth -Full

# Get overall cluster status
Get-CephStatus

# Get cluster configuration
Get-CephConfig
Get-CephConfig -Name 'osd_pool_default_size'

#endregion

#region Host Management

# List all hosts in the cluster
Get-CephHost

# Get details for a specific host
Get-CephHost -Hostname 'ceph-node01'

# Get storage devices on a host
Get-CephHostDevice -Hostname 'ceph-node01'

# Get daemons running on a host
Get-CephHostDaemon -Hostname 'ceph-node01'

#endregion

#region Pool Management

# List all pools
Get-CephPool

# Get a specific pool
Get-CephPool -Name 'rbd'

# Create a new replicated pool
New-CephPool -Name 'mydata' -Size 3 -PGNum 128

# Create an erasure-coded pool
New-CephPool -Name 'archivedata' -Type ErasureCoded -ErasureCodeProfile 'default'

# Modify pool settings
Set-CephPool -Name 'mydata' -Size 2

# Delete a pool (requires confirmation)
Remove-CephPool -Name 'mydata'

# Force delete without confirmation
Remove-CephPool -Name 'mydata' -Force

#endregion

#region OSD Management

# List all OSDs
Get-CephOSD

# Get a specific OSD
Get-CephOSD -Id 0

# Get OSD tree (CRUSH hierarchy)
Get-CephOSDTree

# Modify OSD state
Set-CephOSD -Id 0 -Down   # Mark OSD as down
Set-CephOSD -Id 0 -Out    # Mark OSD as out

#endregion

#region Monitor Management

# List all monitors
Get-CephMonitor

#endregion

#region RBD (Block Device) Management

# List all RBD images
Get-CephRBDImage

# List images in a specific pool
Get-CephRBDImage -Pool 'rbd'

# Get a specific image
Get-CephRBDImage -Pool 'rbd' -Name 'myimage'

# Create a new RBD image (10GB)
New-CephRBDImage -Pool 'rbd' -Name 'myimage' -Size 10GB

# Delete an RBD image
Remove-CephRBDImage -Pool 'rbd' -Name 'myimage'

# List snapshots
Get-CephRBDSnapshot -Pool 'rbd' -Image 'myimage'

# Create a snapshot
New-CephRBDSnapshot -Pool 'rbd' -Image 'myimage' -Name 'snap1'

#endregion

#region CephFS Management

# List all CephFS filesystems
Get-CephFS

# Get a specific filesystem
Get-CephFS -Name 'cephfs'

# List directory contents
Get-CephFSDirectory -FileSystem 'cephfs' -Path '/'

#endregion

#region User Management

# List RADOS authentication users (ceph auth)
Get-CephUser

# List Ceph Dashboard users
Get-CephDashboardUser

#endregion

#region NVMe-oF Management

# List NVMe-oF gateways
Get-CephNVMeoFGateway

# List subsystems
Get-CephNVMeoFSubsystem

# Create a subsystem
New-CephNVMeoFSubsystem -NQN 'nqn.2024-01.com.example:nvme01'

# List namespaces in a subsystem
Get-CephNVMeoFNamespace -NQN 'nqn.2024-01.com.example:nvme01'

# Create a namespace (expose RBD image)
New-CephNVMeoFNamespace -NQN 'nqn.2024-01.com.example:nvme01' `
    -Pool 'rbd' -Image 'myimage'

# List hosts allowed to connect
Get-CephNVMeoFHost -NQN 'nqn.2024-01.com.example:nvme01'

# Allow a host to connect
Add-CephNVMeoFHost -NQN 'nqn.2024-01.com.example:nvme01' `
    -HostNQN 'nqn.2024-01.com.example:client01'

# Remove a host
Remove-CephNVMeoFHost -NQN 'nqn.2024-01.com.example:nvme01' `
    -HostNQN 'nqn.2024-01.com.example:client01'

# Remove a namespace
Remove-CephNVMeoFNamespace -NQN 'nqn.2024-01.com.example:nvme01' -NamespaceId 1

# Remove a subsystem
Remove-CephNVMeoFSubsystem -NQN 'nqn.2024-01.com.example:nvme01'

#endregion

#region SMB Management

# List SMB clusters
Get-CephSMBCluster

# Create an SMB cluster
New-CephSMBCluster -ClusterId 'smb01' -AuthMode 'user'

# Join to Active Directory
Join-CephSMBActiveDirectory -ClusterId 'smb01' `
    -DomainName 'example.com' `
    -Credential (Get-Credential)

# List SMB shares
Get-CephSMBShare

# Create an SMB share
New-CephSMBShare -ClusterId 'smb01' -ShareId 'share01' `
    -FileSystem 'cephfs' -Path '/exports/share01'

# Modify an SMB share
Set-CephSMBShare -ClusterId 'smb01' -ShareId 'share01' -ReadOnly

# Remove an SMB share
Remove-CephSMBShare -ClusterId 'smb01' -ShareId 'share01'

# List users and groups
Get-CephSMBUserGroup -ClusterId 'smb01'

# Remove an SMB cluster
Remove-CephSMBCluster -ClusterId 'smb01'

#endregion

#region Raw API Responses

# All Get-* cmdlets support the -Raw switch to return unprocessed API responses
Get-CephHealth -Raw
Get-CephPool -Raw
Get-CephOSD -Raw

#endregion

#region Pipeline Examples

# Get all pools and their PG counts
Get-CephPool | Select-Object Name, PGNum, Size

# Find OSDs that are down
Get-CephOSD | Where-Object { -not $_.Up }

# Get all RBD images larger than 100GB
Get-CephRBDImage | Where-Object { $_.Size -gt 100GB }

# Export cluster health report
Get-CephHealth -Full | ConvertTo-Json -Depth 10 | Out-File 'health-report.json'

#endregion
