# Module 1: Virtual Network Fundamentals

## Overview

This module covers the foundation of all Azure networking - Virtual Networks (VNets). You'll learn how to design address spaces, create subnets for different purposes, and understand how Azure handles routing by default.

## Learning Objectives

By completing this exercise, you will:

1. **Master CIDR notation** and subnet calculation in Azure context
2. **Understand address space planning** for enterprise scenarios
3. **Learn about reserved IP addresses** in each Azure subnet
4. **Observe default system routes** and understand Azure's routing behavior
5. **Prepare subnets** for specific Azure services (delegation basics)

## Prerequisites

- Azure CLI installed and logged in (`az login`)
- An Azure subscription with Contributor access
- Basic understanding of IP addressing

## Architecture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        Virtual Network: 10.0.0.0/16                        │
│                                                                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   Web Subnet    │  │   App Subnet    │  │    DB Subnet    │             │
│  │  10.0.1.0/24    │  │  10.0.2.0/24    │  │  10.0.3.0/24    │             │
│  │                 │  │                 │  │                 │             │
│  │  ┌──────────┐   │  │                 │  │                 │             │
│  │  │  web-vm  │   │  │                 │  │                 │             │
│  │  │ 10.0.1.4 │   │  │                 │  │                 │             │
│  │  └──────────┘   │  │                 │  │                 │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
│                                                                            │
│  ┌─────────────────┐                                                       │
│  │ Management      │                                                       │
│  │  10.0.255.0/24  │  ← Placed at end of address space for easy expansion  │
│  └─────────────────┘                                                       │
└────────────────────────────────────────────────────────────────────────────┘
```

## Key Networking Concepts

### 1. Address Space Planning

When designing a VNet address space, consider:

| Consideration | Recommendation |
|---------------|----------------|
| **Size** | Start larger than needed; shrinking is harder than expanding |
| **Overlap** | Ensure no overlap with on-premises or other VNets you'll peer with |
| **RFC 1918** | Use private ranges: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 |
| **Growth** | Plan for 3-5 years of growth |

### 2. Reserved IP Addresses

Azure reserves **5 IP addresses** in each subnet:

| Address | Purpose |
|---------|---------|
| x.x.x.0 | Network address |
| x.x.x.1 | Default gateway (Azure's internal router) |
| x.x.x.2 | Azure DNS mapping |
| x.x.x.3 | Azure DNS mapping |
| x.x.x.255 | Broadcast address (for /24) |

**Example for 10.0.1.0/24:**
- Reserved: 10.0.1.0, 10.0.1.1, 10.0.1.2, 10.0.1.3, 10.0.1.255
- Usable: 10.0.1.4 - 10.0.1.254 (251 addresses)

### 3. Subnet Sizing Guide

| Subnet Size | Total IPs | Usable IPs | Use Case |
|-------------|-----------|------------|----------|
| /29 | 8 | 3 | Minimum for most services |
| /28 | 16 | 11 | Small service deployments |
| /27 | 32 | 27 | GatewaySubnet minimum |
| /26 | 64 | 59 | AzureBastionSubnet, AzureFirewallSubnet |
| /24 | 256 | 251 | Standard workload subnets |
| /16 | 65,536 | 65,531 | Large VNet address space |

### 4. System Routes

Azure automatically creates these routes for every subnet:

| Source | Address Prefix | Next Hop |
|--------|----------------|----------|
| Default | VNet address space | Virtual network |
| Default | 0.0.0.0/0 | Internet |
| Default | 10.0.0.0/8 | None (drop) |
| Default | 172.16.0.0/12 | None (drop) |
| Default | 192.168.0.0/16 | None (drop) |

The "None" routes for RFC 1918 ranges prevent routing to non-existent networks.

### 5. Special Subnet Names

Some Azure services require specially named subnets:

| Service | Required Subnet Name | Min Size |
|---------|---------------------|----------|
| VPN Gateway | GatewaySubnet | /27 |
| Azure Bastion | AzureBastionSubnet | /26 |
| Azure Firewall | AzureFirewallSubnet | /26 |
| App Service Integration | Any (delegated) | /28 |

## Exercise Steps

### Step 1: Deploy the Infrastructure

```bash
# Navigate to the exercise directory
cd exercises/01-vnet-fundamentals

# Make scripts executable
chmod +x deploy.sh cleanup.sh

# Deploy (creates resource group and all resources)
./deploy.sh
```

### Step 2: Explore the VNet in Azure Portal

1. Navigate to the Resource Group `rg-learn-vnet-fundamentals`
2. Open the Virtual Network `vnet-learn`
3. Explore:
   - **Address space** - Note how it's configured
   - **Subnets** - See the 4 subnets and their ranges
   - **Connected devices** - Find the VM's NIC

### Step 3: Examine Effective Routes

```bash
# Get the VM's NIC name
az network nic list \
  --resource-group rg-learn-vnet-fundamentals \
  --query "[].name" -o tsv

# View effective routes (replace <nic-name> with actual name)
az network nic show-effective-route-table \
  --resource-group rg-learn-vnet-fundamentals \
  --name <nic-name> \
  --output table
```

**Expected output shows:**
- Route to 10.0.0.0/16 → VirtualNetwork (traffic stays in VNet)
- Route to 0.0.0.0/0 → Internet (default internet route)
- Routes to RFC 1918 ranges → None (blackholed)

### Step 4: Test Connectivity from the VM

```bash
# Get the VM's public IP
PUBLIC_IP=$(az vm show \
  --resource-group rg-learn-vnet-fundamentals \
  --name vm-web \
  --show-details \
  --query publicIps -o tsv)

# SSH into the VM (use the password you provided during deployment)
ssh azureuser@$PUBLIC_IP

# Inside the VM, check the network configuration
ip addr show
ip route show

# Test DNS resolution (Azure DNS at 168.63.129.16)
cat /etc/resolv.conf
nslookup microsoft.com

# Test outbound internet connectivity
curl -s ifconfig.me

# Exit the VM
exit
```

### Step 5: Explore Subnet Details via CLI

```bash
# List all subnets with their address ranges
az network vnet subnet list \
  --resource-group rg-learn-vnet-fundamentals \
  --vnet-name vnet-learn \
  --output table

# Get detailed subnet information including available IPs
az network vnet subnet show \
  --resource-group rg-learn-vnet-fundamentals \
  --vnet-name vnet-learn \
  --name snet-web \
  --query "{Name:name, AddressPrefix:addressPrefix, AvailableIPs:addressPrefixes}" \
  --output table
```

### Step 6: Understand IP Address Assignment

```bash
# Check the VM's private IP configuration
az network nic ip-config list \
  --resource-group rg-learn-vnet-fundamentals \
  --nic-name nic-vm-web \
  --output table

# Note: The first available IP is 10.0.1.4 (after reserved addresses)
```

## Verification Checklist

- [ ] VNet created with address space 10.0.0.0/16
- [ ] Four subnets created with correct CIDR ranges
- [ ] VM deployed in web subnet with IP 10.0.1.4
- [ ] Can view effective routes showing system routes
- [ ] Can SSH to VM and verify network configuration
- [ ] Understand why first usable IP is .4, not .1

## Deep Dive: The Bicep Template

Open `main.bicep` and study:

1. **VNet resource** - How address space is defined
2. **Subnet definitions** - Inline vs separate resources
3. **NIC configuration** - How it references the subnet
4. **Public IP** - SKU and allocation method

Each section has detailed comments explaining the networking implications.

## Cleanup

```bash
# Remove all resources when done
./cleanup.sh
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "Address space overlaps" | Ensure no other VNets use 10.0.0.0/16 |
| "Subnet not found" | Wait a few seconds for ARM to propagate |
| "Cannot SSH" | Check NSG rules allow port 22 |

## What's Next?

In **Module 2: Network Security**, you'll:
- Add NSGs to control traffic between subnets
- Learn about security rule evaluation order
- Implement Application Security Groups

## Additional Resources

- [Azure VNet documentation](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview)
- [Plan virtual networks](https://learn.microsoft.com/azure/virtual-network/virtual-network-vnet-plan-design-arm)
- [Subnet calculator](https://www.calculator.net/ip-subnet-calculator.html)
