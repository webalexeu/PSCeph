# PSCeph

A PowerShell module for managing Ceph clusters through the Ceph Dashboard REST API.

## Features

- **Connection Management** - Secure authentication with automatic token refresh
- **Cluster Monitoring** - Health status, configuration, hosts, and daemons
- **Pool Management** - Create, modify, and remove storage pools
- **OSD Management** - View and manage Object Storage Daemons
- **RBD Images** - Manage RADOS Block Device images and snapshots
- **CephFS** - Browse CephFS filesystems and directories
- **NVMe-oF** - Manage NVMe over Fabrics gateways, subsystems, and namespaces
- **SMB** - Manage SMB clusters and shares
- **Cross-Platform** - Works on PowerShell 5.1, PowerShell 7, and PowerShell Core (Linux/macOS)

## Prerequisites

- PowerShell 5.1 or later
- Ceph cluster with Dashboard enabled (Ceph Luminous or later)
- Dashboard API access credentials

## Installation

To install the module from the PowerShell Gallery:

```powershell
Install-PSResource -Name PSCeph
Import-Module -Name PSCeph
```

## Quick Start

### Connect to a Ceph Cluster

```powershell
# Connect with interactive credential prompt
Connect-Ceph -Server 'ceph-mgr.local' -Credential (Get-Credential)

# Connect with self-signed certificate
Connect-Ceph -Server '192.168.1.100' -Port 8443 -Credential $cred -SkipCertificateCheck
```

### Check Cluster Health

```powershell
# Get basic health status
Get-CephHealth

# Get detailed health information
Get-CephHealth -Full

# Get raw API response
Get-CephHealth -Raw
```

### Manage Pools

```powershell
# List all pools
Get-CephPool

# List pools with statistics
Get-CephPool -Stats

# Create a new pool
New-CephPool -Name 'mypool' -PgNum 128 -Size 3

# Remove a pool
Remove-CephPool -Name 'mypool' -Force
```

### Manage RBD Images

```powershell
# List RBD images in a pool
Get-CephRBDImage -PoolName 'rbd'

# Get a specific image
Get-CephRBDImage -PoolName 'rbd' -ImageName 'myimage'

# Create a new RBD image
New-CephRBDImage -PoolName 'rbd' -ImageName 'newimage' -Size 10GB

# Create a snapshot
New-CephRBDSnapshot -PoolName 'rbd' -ImageName 'myimage' -SnapshotName 'snap1'
```

### View OSDs and Monitors

```powershell
# List all OSDs
Get-CephOSD

# Get OSD tree (CRUSH map)
Get-CephOSDTree

# List monitors
Get-CephMonitor
```

### Browse CephFS

```powershell
# List filesystems
Get-CephFS

# List directory contents
Get-CephFSDirectory -Filesystem 'cephfs' -Path '/data'
```

### Manage NVMe-oF

```powershell
# List NVMe-oF gateways
Get-CephNVMeoFGateway

# List subsystems
Get-CephNVMeoFSubsystem

# Create a new subsystem
New-CephNVMeoFSubsystem -Nqn 'nqn.2024-01.io.ceph:mysub'

# Add a namespace
New-CephNVMeoFNamespace -Nqn 'nqn.2024-01.io.ceph:mysub' -PoolName 'nvmeof' -ImageName 'vol1'
```

### Manage SMB Shares

```powershell
# List SMB clusters
Get-CephSMBCluster

# List shares in a cluster
Get-CephSMBShare -ClusterId 'smb1'

# Create a new share
New-CephSMBShare -ClusterId 'smb1' -ShareName 'data' -Filesystem 'cephfs' -Path '/data'
```

### Disconnect

```powershell
Disconnect-Ceph
```

## Raw Output

All Get-* cmdlets support a `-Raw` switch that returns the unprocessed API response:

```powershell
# Formatted output (default)
Get-CephPool

# Raw API response
Get-CephPool -Raw
```

## Available Cmdlets

### Connection
- `Connect-Ceph` - Establish connection to Ceph Dashboard
- `Disconnect-Ceph` - Close the connection
- `Get-CephConnection` - Get current connection information

### Cluster
- `Get-CephHealth` - Get cluster health status
- `Get-CephStatus` - Get overall cluster status
- `Get-CephConfig` - Get cluster configuration
- `Get-CephHost` - List cluster hosts
- `Get-CephHostDevice` - List devices on a host
- `Get-CephHostDaemon` - List daemons on a host

### Pool
- `Get-CephPool` - List storage pools
- `New-CephPool` - Create a pool
- `Set-CephPool` - Modify a pool
- `Remove-CephPool` - Delete a pool

### OSD
- `Get-CephOSD` - List OSDs
- `Set-CephOSD` - Modify OSD state (in/out/down)
- `Get-CephOSDTree` - Get OSD tree structure

### Monitor
- `Get-CephMonitor` - List monitors

### RBD
- `Get-CephRBDImage` - List RBD images
- `New-CephRBDImage` - Create an RBD image
- `Remove-CephRBDImage` - Delete an RBD image
- `Get-CephRBDSnapshot` - List snapshots
- `New-CephRBDSnapshot` - Create a snapshot

### CephFS
- `Get-CephFS` - List filesystems
- `Get-CephFSDirectory` - List directory contents

### Auth
- `Get-CephUser` - List RADOS users
- `Get-CephDashboardUser` - List Dashboard users

### NVMe-oF
- `Get-CephNVMeoFGateway` - List gateways
- `Get-CephNVMeoFSubsystem` - List subsystems
- `New-CephNVMeoFSubsystem` - Create a subsystem
- `Remove-CephNVMeoFSubsystem` - Delete a subsystem
- `Get-CephNVMeoFNamespace` - List namespaces
- `New-CephNVMeoFNamespace` - Create a namespace
- `Remove-CephNVMeoFNamespace` - Delete a namespace
- `Get-CephNVMeoFHost` - List allowed hosts
- `Add-CephNVMeoFHost` - Add a host
- `Remove-CephNVMeoFHost` - Remove a host

### SMB
- `Get-CephSMBCluster` - List SMB clusters
- `New-CephSMBCluster` - Create an SMB cluster
- `Remove-CephSMBCluster` - Delete an SMB cluster
- `Get-CephSMBShare` - List SMB shares
- `New-CephSMBShare` - Create an SMB share
- `Set-CephSMBShare` - Modify an SMB share
- `Remove-CephSMBShare` - Delete an SMB share
- `Get-CephSMBUsersGroups` - List SMB users and groups
- `Join-CephSMBActiveDirectory` - Join Active Directory domain

## Getting Help

Use PowerShell's built-in help system:

```powershell
# List all commands
Get-Command -Module PSCeph

# Get help for a command
Get-Help Get-CephPool -Full

# Get examples
Get-Help New-CephRBDImage -Examples
```

## Contributing

Contributions are welcome! Please read the [Contribution guidelines](CONTRIBUTING.md) for more information.

### For Users

If you experience issues or have feature requests, please submit them on the [Issues](../../issues) page.

### For Developers

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests with `Invoke-Pester`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

- [Ceph](https://ceph.io/) - The open-source distributed storage system
- [PSModule Framework](https://github.com/PSModule/Process-PSModule) - For building, testing, and publishing
