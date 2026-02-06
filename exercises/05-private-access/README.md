# Module 5: Private Access - Private Endpoints & Service Endpoints

## Overview

This module covers how to access Azure PaaS services privately, without traversing the public internet. You'll learn the differences between Service Endpoints and Private Endpoints, and when to use each.

## Learning Objectives

By completing this exercise, you will:

1. **Understand Service Endpoints** - How they optimize routing to Azure services
2. **Master Private Endpoints** - Full private connectivity to PaaS services
3. **Configure Private DNS Zones** - Critical for private endpoint name resolution
4. **Compare approaches** - When to use which technology
5. **Disable public access** - Complete private connectivity

## Prerequisites

- Completed Modules 1-3
- Understanding of DNS concepts

## Architecture

### Service Endpoints vs Private Endpoints

```
                        SERVICE ENDPOINTS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌─────────────────┐                        ┌─────────────────────────────┐ │
│  │     VNet        │   Optimized Route      │    Azure Storage            │ │
│  │   10.0.0.0/16   │   (Azure backbone)     │    Public IP: 20.x.x.x      │ │
│  │                 │ ─────────────────────► │                             │ │
│  │   VM: 10.0.1.4  │   Still uses public IP │    Firewall: Allow VNet     │ │
│  └─────────────────┘   but via backbone     └─────────────────────────────┘ │
│                                                                             │
│  Traffic stays on Azure backbone, but uses PUBLIC IP of the service        │
└─────────────────────────────────────────────────────────────────────────────┘

                        PRIVATE ENDPOINTS
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌──────────────────────────────────────┐   ┌───────────────────────────┐  │
│  │              VNet                     │   │    Azure Storage          │  │
│  │           10.0.0.0/16                 │   │    (Public access OFF)    │  │
│  │                                       │   │                           │  │
│  │  ┌──────────────┐  ┌──────────────┐  │   │                           │  │
│  │  │     VM       │  │Private Endpt │◄─┼───┼──► Private connection     │  │
│  │  │  10.0.1.4    │  │  10.0.2.4    │  │   │                           │  │
│  │  └──────────────┘  └──────────────┘  │   └───────────────────────────┘  │
│  │         │                 ▲           │                                  │
│  │         │     DNS         │           │   ┌───────────────────────────┐  │
│  │         └────────────────►│           │   │   Private DNS Zone        │  │
│  │  storageacct.blob...      │           │   │   privatelink.blob...     │  │
│  │  resolves to 10.0.2.4     │           │   │   A: 10.0.2.4             │  │
│  │                           │           │   └───────────────────────────┘  │
│  └───────────────────────────┼───────────┘                                  │
│                              │                                              │
│  Traffic uses PRIVATE IP, never touches public internet                    │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Key Networking Concepts

### 1. Service Endpoints vs Private Endpoints

| Feature | Service Endpoint | Private Endpoint |
|---------|------------------|------------------|
| **IP used** | Public IP (via backbone) | Private IP in VNet |
| **DNS** | No change needed | Requires Private DNS |
| **Cost** | Free | ~$7.50/month + data |
| **Security** | Service firewall rules | Full network isolation |
| **On-prem access** | No | Yes (via VPN/ER) |
| **Cross-region** | No | Yes |
| **Service support** | Limited services | Most PaaS services |

### 2. Private Endpoint Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                     PRIVATE ENDPOINT ANATOMY                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. PRIVATE ENDPOINT RESOURCE                                        │
│     └── Creates a NIC in your subnet                                │
│     └── Gets a private IP from subnet range                         │
│     └── Links to target PaaS service                                │
│                                                                      │
│  2. GROUP ID (subresource)                                          │
│     └── Specifies which part of service to connect                  │
│     └── Storage: blob, file, table, queue, web, dfs                 │
│     └── SQL: sqlServer                                              │
│     └── Key Vault: vault                                            │
│                                                                      │
│  3. PRIVATE DNS ZONE                                                │
│     └── Records for privatelink.*.core.windows.net                  │
│     └── Links to VNet for resolution                                │
│     └── Auto-registration of endpoint IP                            │
│                                                                      │
│  4. TARGET SERVICE                                                   │
│     └── PaaS service (Storage, SQL, Key Vault, etc.)               │
│     └── Can disable public access entirely                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3. DNS Resolution Flow

```
Without Private DNS (Wrong - will fail):
VM → DNS Query: mystorageacct.blob.core.windows.net
   → Returns: 20.150.x.x (public IP)
   → Connection blocked (public access disabled)

With Private DNS (Correct):
VM → DNS Query: mystorageacct.blob.core.windows.net
   → Azure DNS → Query CNAME: mystorageacct.privatelink.blob.core.windows.net
   → Private DNS Zone → Returns: 10.0.2.4 (private IP)
   → Connection succeeds to Private Endpoint
```

### 4. Private DNS Zone Names

| Service | Private DNS Zone |
|---------|------------------|
| Blob Storage | privatelink.blob.core.windows.net |
| File Storage | privatelink.file.core.windows.net |
| Queue Storage | privatelink.queue.core.windows.net |
| Table Storage | privatelink.table.core.windows.net |
| Azure SQL | privatelink.database.windows.net |
| Key Vault | privatelink.vaultcore.azure.net |
| Azure Web Apps | privatelink.azurewebsites.net |
| Event Hub | privatelink.servicebus.windows.net |
| Cosmos DB | privatelink.documents.azure.com |

### 5. Network Policies for Private Endpoints

By default, NSG and UDR don't apply to private endpoint traffic. You can enable network policies:

```bicep
subnet: {
  properties: {
    privateEndpointNetworkPolicies: 'Enabled'  // Apply NSG/UDR
  }
}
```

## Exercise 5.1: Service Endpoints

### Step 1: Deploy Infrastructure

```bash
cd exercises/05-private-access

./deploy-service-endpoints.sh
```

### Step 2: Test Without Service Endpoint

```bash
# SSH to VM
ssh azureuser@<vm-public-ip>

# Try to access storage - may work initially
curl -I https://<storageaccount>.blob.core.windows.net/

# Exit
exit
```

### Step 3: Enable Service Endpoint

```bash
# Enable service endpoint on subnet
az network vnet subnet update \
  --resource-group rg-learn-private-access \
  --vnet-name vnet-private-access \
  --name snet-workload \
  --service-endpoints Microsoft.Storage

# Restrict storage to VNet only
az storage account network-rule add \
  --resource-group rg-learn-private-access \
  --account-name <storageaccount> \
  --vnet-name vnet-private-access \
  --subnet snet-workload
  
az storage account update \
  --resource-group rg-learn-private-access \
  --name <storageaccount> \
  --default-action Deny
```

### Step 4: Test With Service Endpoint

```bash
# SSH to VM
ssh azureuser@<vm-public-ip>

# Access storage - should work through service endpoint
curl -I https://<storageaccount>.blob.core.windows.net/

# Try from your local machine - should be DENIED
curl -I https://<storageaccount>.blob.core.windows.net/
# Result: 403 Forbidden

exit
```

## Exercise 5.2: Private Endpoints

### Step 1: Deploy Infrastructure

```bash
./deploy.sh
```

This deploys:
- VNet with two subnets
- Storage Account with Private Endpoint
- Private DNS Zone linked to VNet
- VM for testing

### Step 2: Understand DNS Resolution

```bash
# SSH to VM
ssh azureuser@<vm-public-ip>

# Check DNS resolution
nslookup <storageaccount>.blob.core.windows.net

# Expected output:
# Name: <storageaccount>.privatelink.blob.core.windows.net
# Address: 10.0.2.4 (private IP!)

# The CNAME chain:
# <storageaccount>.blob.core.windows.net
#   → <storageaccount>.privatelink.blob.core.windows.net
#   → 10.0.2.4 (from Private DNS Zone)
```

### Step 3: Test Private Connectivity

```bash
# From VM, access storage via private endpoint
curl -I https://<storageaccount>.blob.core.windows.net/

# Should work! Connection goes to private IP

# List blobs (if container exists)
az storage blob list \
  --account-name <storageaccount> \
  --container-name test \
  --auth-mode login
```

### Step 4: Verify Public Access is Blocked

```bash
# From your LOCAL machine (not the VM)
nslookup <storageaccount>.blob.core.windows.net

# If you don't have private DNS, returns public IP
# But public access is disabled!

curl -I https://<storageaccount>.blob.core.windows.net/
# Result: Connection refused or 403

# This proves only private endpoint access works
```

### Step 5: Examine Private DNS Zone

```bash
# List DNS records in private zone
az network private-dns record-set list \
  --resource-group rg-learn-private-access \
  --zone-name privatelink.blob.core.windows.net \
  --output table

# Check VNet link
az network private-dns link vnet list \
  --resource-group rg-learn-private-access \
  --zone-name privatelink.blob.core.windows.net \
  --output table
```

### Step 6: Examine Private Endpoint

```bash
# View private endpoint details
az network private-endpoint show \
  --resource-group rg-learn-private-access \
  --name pe-storage \
  --query "{Name:name, PrivateIP:customDnsConfigs[0].ipAddresses[0], FQDN:customDnsConfigs[0].fqdn}"

# View the NIC created for private endpoint
az network nic list \
  --resource-group rg-learn-private-access \
  --query "[?contains(name,'pe-storage')].{Name:name, PrivateIP:ipConfigurations[0].privateIPAddress}" \
  --output table
```

## Verification Checklist

### Service Endpoints
- [ ] Subnet has service endpoint enabled
- [ ] Storage account restricted to VNet
- [ ] VM can access storage
- [ ] External access is denied

### Private Endpoints
- [ ] Private endpoint created with private IP
- [ ] Private DNS zone created and linked
- [ ] DNS resolves to private IP from VM
- [ ] VM can access storage via private endpoint
- [ ] Public access disabled on storage account
- [ ] External access fails completely

## Deep Dive: The Bicep Template

Study `main.bicep` to understand:

1. **Private Endpoint resource** - privateLinkServiceConnections
2. **Group IDs** - How to specify blob, sql, etc.
3. **Private DNS Zone** - Zone name patterns
4. **Private DNS Zone Link** - Connecting zone to VNet
5. **DNS Zone Group** - Auto-creating DNS records

## Cleanup

```bash
./cleanup.sh
```

## Common Issues

| Issue | Solution |
|-------|----------|
| DNS returns public IP | Verify private DNS zone is linked to VNet |
| Connection timeout | Check private endpoint approval status |
| 403 from VM | Verify VM is in VNet linked to private DNS |
| Can't disable public access | Remove any service endpoints first |

## What's Next?

In **Module 6: Load Balancer**, you'll:
- Deploy Azure Load Balancer
- Understand L4 load balancing
- Configure health probes and backend pools

## Additional Resources

- [Private Endpoint documentation](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)
- [Service Endpoints documentation](https://learn.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview)
- [Private DNS Zones](https://learn.microsoft.com/azure/dns/private-dns-overview)
