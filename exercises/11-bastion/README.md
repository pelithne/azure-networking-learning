# Module 11: Azure Bastion

## Overview

Azure Bastion provides secure RDP/SSH connectivity to VMs directly through the Azure portal without exposing public IPs on the VMs.

## Key Concepts

### Why Bastion?

- **No public IP** on VMs - reduced attack surface
- **No NSG rules** needed for RDP/SSH from internet
- **TLS encryption** - browser to Bastion
- **Protection** against port scanning

### Bastion SKUs

| SKU | Features |
|-----|----------|
| **Basic** | RDP/SSH via portal, 2 instances |
| **Standard** | + Native client, shareable links, file transfer, 50 instances |
| **Developer** | Free tier, limited features |

### Subnet Requirements

- Name: **AzureBastionSubnet** (exact)
- Minimum size: /26 (Basic) or /26 (Standard)
- **No NSG required** - but can add for extra control

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                     Azure Portal                     │
│                 (Browser-based access)               │
└───────────────────────────┬──────────────────────────┘
                            │ TLS/443
                            ▼
┌───────────────────────────────────────────────────────┐
│                    Virtual Network                    │
│  ┌─────────────────────────────────────────────────┐  │
│  │           AzureBastionSubnet (/26)              │  │
│  │                                                  │  │
│  │    ┌──────────────────────────────┐             │  │
│  │    │      Azure Bastion           │             │  │
│  │    │      (Managed PaaS)          │             │  │
│  │    └──────────────────────────────┘             │  │
│  └─────────────────────────────────────────────────┘  │
│                           │                           │
│                    RDP (3389) / SSH (22)             │
│                           │                           │
│  ┌─────────────────────────────────────────────────┐  │
│  │              Workload Subnet                     │  │
│  │                                                  │  │
│  │    ┌──────────┐           ┌──────────┐          │  │
│  │    │   VM-1   │           │   VM-2   │          │  │
│  │    │ No Pub IP│           │ No Pub IP│          │  │
│  │    └──────────┘           └──────────┘          │  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

## Deployment

```bash
cd exercises/11-bastion
./deploy.sh
```

## Access VMs

1. Go to Azure Portal → VM → Connect → Bastion
2. Enter username/password
3. Click "Connect" - opens in browser

## Native Client (Standard SKU)

```bash
# Install Azure CLI with Bastion extension
az extension add -n bastion

# Connect via native RDP/SSH client
az network bastion ssh -n bas-hub -g rg-learn-bastion \
  --target-resource-id /subscriptions/.../vm-workload \
  --auth-type password --username azureuser
```
