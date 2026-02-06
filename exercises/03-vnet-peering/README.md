# Module 3: VNet Peering

## Overview

VNet Peering enables connectivity between Azure Virtual Networks. This module covers both regional and global peering, peering properties, and the critical concept of non-transitivity.

## Learning Objectives

By completing this exercise, you will:

1. **Understand peering types** - Regional vs Global VNet peering
2. **Master peering properties** - AllowForwardedTraffic, AllowGatewayTransit, UseRemoteGateways
3. **Learn non-transitivity** - Why VNet A → B and B → C doesn't mean A → C
4. **Configure bidirectional peering** - Peering must be created from both sides
5. **Understand peering states** - Initiated, Connected, Disconnected

## Prerequisites

- Completed Modules 1-2
- Understanding of VNets and NSGs

## Architecture

```
                         REGIONAL PEERING
    ┌──────────────────────────────────────────────────────────────────┐
    │                        East US 2                                  │
    │                                                                   │
    │  ┌─────────────────────┐         ┌─────────────────────┐         │
    │  │   VNet-Hub          │◄───────►│   VNet-Spoke1       │         │
    │  │   10.0.0.0/16       │ Peering │   10.1.0.0/16       │         │
    │  │                     │         │                     │         │
    │  │  ┌───────────────┐  │         │  ┌───────────────┐  │         │
    │  │  │   vm-hub      │  │         │  │   vm-spoke1   │  │         │
    │  │  │   10.0.1.4    │  │         │  │   10.1.1.4    │  │         │
    │  │  └───────────────┘  │         │  └───────────────┘  │         │
    │  └─────────────────────┘         └─────────────────────┘         │
    │           │                                                       │
    │           │ Peering                                               │
    │           ▼                                                       │
    │  ┌─────────────────────┐                                         │
    │  │   VNet-Spoke2       │         NO DIRECT CONNECTIVITY          │
    │  │   10.2.0.0/16       │◄ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┤ │
    │  │                     │         (Non-transitive)                │
    │  │  ┌───────────────┐  │                                         │
    │  │  │   vm-spoke2   │  │   Spoke1 cannot reach Spoke2           │
    │  │  │   10.2.1.4    │  │   without explicit peering or UDRs     │
    │  │  └───────────────┘  │                                         │
    │  └─────────────────────┘                                         │
    └──────────────────────────────────────────────────────────────────┘
```

## Key Networking Concepts

### 1. VNet Peering Types

| Type | Description | Latency | Cost |
|------|-------------|---------|------|
| **Regional** | Same Azure region | ~1ms | Lower egress |
| **Global** | Different Azure regions | Higher (cross-region) | Higher egress |

### 2. Peering Properties Explained

| Property | Default | Purpose |
|----------|---------|---------|
| `allowVirtualNetworkAccess` | true | Allow VNet traffic (set false to block) |
| `allowForwardedTraffic` | false | Accept traffic forwarded by NVA in peer VNet |
| `allowGatewayTransit` | false | Allow peer to use your VPN/ExpressRoute gateway |
| `useRemoteGateways` | false | Use peer's VPN/ExpressRoute gateway |

### 3. Peering States

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Initiated    │────►│    Connected    │────►│  Disconnected   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
 (One side created)      (Both sides done)      (One side deleted)
```

**Critical:** Both sides must create peering. After one side creates it, state is "Initiated". When both sides create it, state becomes "Connected".

### 4. Non-Transitivity

```
VNet-A ◄──── peering ────► VNet-B ◄──── peering ────► VNet-C
   │                                                      │
   └──────────────── NO connectivity ─────────────────────┘
```

Peering is **NOT transitive**:
- VNet-A can reach VNet-B ✓
- VNet-B can reach VNet-C ✓
- VNet-A **cannot** reach VNet-C ✗

**Solutions for spoke-to-spoke:**
1. Direct peering between spokes (creates mesh)
2. Route through hub NVA/Firewall (hub-spoke pattern)
3. Use Virtual WAN (managed routing)

### 5. Address Space Rules

| Rule | Consequence |
|------|-------------|
| Spaces **cannot overlap** | Error on peering creation |
| Can add space to peered VNet | Must sync peering (re-create or update) |
| Cannot remove in-use space | Blocks removal |

### 6. Peering vs VPN

| Feature | VNet Peering | VNet-to-VNet VPN |
|---------|--------------|------------------|
| Encryption | No (private backbone) | Yes (IPsec) |
| Latency | Lower | Higher |
| Bandwidth | Very high | Gateway SKU limited |
| Setup | Simple | Complex (gateways needed) |
| Cost | Egress only | Gateway + egress |
| Use case | Typical VNet connectivity | Compliance requiring encryption |

## Exercise Steps

### Step 1: Deploy the Infrastructure

```bash
cd exercises/03-vnet-peering

chmod +x deploy.sh cleanup.sh

./deploy.sh
```

### Step 2: Verify Initial Connectivity (Before Peering)

```bash
# SSH to hub VM (has public IP)
ssh azureuser@<hub-public-ip>

# Try to ping spoke1 - will FAIL (no peering yet)
ping 10.1.1.4 -c 3
# Result: Network unreachable

# Try spoke2 - will FAIL
ping 10.2.1.4 -c 3  
# Result: Network unreachable

exit
```

### Step 3: Create Peering (Hub ↔ Spoke1)

The Bicep template creates peering, but let's understand the CLI commands:

```bash
# Create peering from Hub to Spoke1
az network vnet peering create \
  --resource-group rg-learn-vnet-peering \
  --name hub-to-spoke1 \
  --vnet-name vnet-hub \
  --remote-vnet vnet-spoke1 \
  --allow-vnet-access \
  --allow-forwarded-traffic

# Create peering from Spoke1 to Hub (REQUIRED - both directions)
az network vnet peering create \
  --resource-group rg-learn-vnet-peering \
  --name spoke1-to-hub \
  --vnet-name vnet-spoke1 \
  --remote-vnet vnet-hub \
  --allow-vnet-access \
  --allow-forwarded-traffic
```

### Step 4: Check Peering State

```bash
# Check peering status
az network vnet peering list \
  --resource-group rg-learn-vnet-peering \
  --vnet-name vnet-hub \
  --output table

# Expected: PeeringState = Connected
```

### Step 5: Test Connectivity (After Peering)

```bash
# SSH to hub VM
ssh azureuser@<hub-public-ip>

# Ping spoke1 - should SUCCEED now
ping 10.1.1.4 -c 3
# Result: 64 bytes from 10.1.1.4

# Ping spoke2 - should SUCCEED (also peered)
ping 10.2.1.4 -c 3
# Result: 64 bytes from 10.2.1.4

exit
```

### Step 6: Verify Non-Transitivity

```bash
# SSH to spoke1 VM (through hub)
ssh azureuser@<hub-public-ip>
ssh azureuser@10.1.1.4

# Try to reach spoke2 FROM spoke1 - will FAIL!
ping 10.2.1.4 -c 3
# Result: Network unreachable

# This proves peering is non-transitive:
# Hub ↔ Spoke1 ✓
# Hub ↔ Spoke2 ✓  
# Spoke1 ↔ Spoke2 ✗ (no direct peering)

exit
exit
```

### Step 7: Examine Effective Routes

```bash
# Get routes that include peered networks
az network nic show-effective-route-table \
  --resource-group rg-learn-vnet-peering \
  --name nic-vm-hub \
  --output table

# You should see routes to:
# - 10.0.0.0/16 (local VNet)
# - 10.1.0.0/16 (peered - Spoke1)
# - 10.2.0.0/16 (peered - Spoke2)
```

### Step 8: Test Peering Properties

```bash
# Disable virtual network access on one side
az network vnet peering update \
  --resource-group rg-learn-vnet-peering \
  --name hub-to-spoke1 \
  --vnet-name vnet-hub \
  --set allowVirtualNetworkAccess=false

# Now test connectivity - should FAIL
ssh azureuser@<hub-public-ip>
ping 10.1.1.4 -c 3
# Result: Fails even though peering exists

# Re-enable
az network vnet peering update \
  --resource-group rg-learn-vnet-peering \
  --name hub-to-spoke1 \
  --vnet-name vnet-hub \
  --set allowVirtualNetworkAccess=true
```

## Verification Checklist

- [ ] Three VNets deployed with non-overlapping address spaces
- [ ] Hub peered to both spokes
- [ ] Hub can reach both spoke VMs
- [ ] Spoke1 cannot reach Spoke2 (non-transitive)
- [ ] Peering state shows "Connected"
- [ ] Effective routes show peered VNet prefixes

## Deep Dive: The Bicep Template

Study `main.bicep` to understand:

1. **Peering resource syntax** - Microsoft.Network/virtualNetworks/virtualNetworkPeerings
2. **Bidirectional configuration** - Two peering resources per connection
3. **Property settings** - allowForwardedTraffic, etc.
4. **Dependencies** - Peering depends on both VNets existing

## Cleanup

```bash
./cleanup.sh
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "Peering state: Initiated" | Create peering from both sides |
| "Address space overlaps" | Check CIDR ranges don't overlap |
| "Remote VNet not found" | Verify VNet name and resource group |
| "Cross-subscription error" | Need permissions on both subscriptions |

## What's Next?

In **Module 4: VPN Gateway**, you'll:
- Deploy a VPN gateway
- Configure point-to-site VPN
- Simulate site-to-site connectivity
- Use gateway transit with peering

## Additional Resources

- [VNet peering overview](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Create peering - CLI](https://learn.microsoft.com/azure/virtual-network/virtual-network-manage-peering)
- [Hub-spoke topology](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
