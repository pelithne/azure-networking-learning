# Module 2: Network Security - NSGs and ASGs

## Overview

This module provides deep understanding of Azure Network Security Groups (NSGs) and Application Security Groups (ASGs). You'll learn how traffic is filtered, rule evaluation order, and best practices for implementing defense-in-depth.

## Learning Objectives

By completing this exercise, you will:

1. **Master NSG rule evaluation order** - Understand how Azure processes security rules
2. **Implement defense-in-depth** - Apply NSGs at both subnet and NIC level
3. **Use service tags** - Simplify rules with Azure-managed IP groups
4. **Configure Application Security Groups** - Group VMs by role, not IP
5. **Understand default rules** - Know what's allowed/denied by default

## Prerequisites

- Completed Module 1 (understanding of VNets and subnets)
- Azure CLI installed and logged in

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Virtual Network: 10.1.0.0/16                             │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     NSG: nsg-snet-web                                 │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │              Subnet: snet-web (10.1.1.0/24)                      │ │  │
│  │  │                                                                  │ │  │
│  │  │   ┌──────────┐           ┌──────────┐                           │ │  │
│  │  │   │ vm-web-1 │           │ vm-web-2 │     ASG: asg-webservers   │ │  │
│  │  │   │ 10.1.1.4 │           │ 10.1.1.5 │                           │ │  │
│  │  │   └──────────┘           └──────────┘                           │ │  │
│  │  └─────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                     │                                       │
│                                     ▼ Allowed: HTTP/HTTPS                   │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     NSG: nsg-snet-app                                 │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │              Subnet: snet-app (10.1.2.0/24)                      │ │  │
│  │  │                                                                  │ │  │
│  │  │   ┌──────────┐           ┌──────────┐                           │ │  │
│  │  │   │ vm-app-1 │           │ vm-app-2 │     ASG: asg-appservers   │ │  │
│  │  │   │ 10.1.2.4 │           │ 10.1.2.5 │                           │ │  │
│  │  │   └──────────┘           └──────────┘                           │ │  │
│  │  └─────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                     │                                       │
│                                     ▼ Allowed: SQL (1433)                   │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     NSG: nsg-snet-db                                  │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │  │
│  │  │              Subnet: snet-db (10.1.3.0/24)                       │ │  │
│  │  │                                                                  │ │  │
│  │  │   ┌──────────┐                                                  │ │  │
│  │  │   │  vm-db   │                            ASG: asg-dbservers    │ │  │
│  │  │   │ 10.1.3.4 │                                                  │ │  │
│  │  │   └──────────┘                                                  │ │  │
│  │  └─────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Networking Concepts

### 1. NSG Rule Evaluation Order

**CRITICAL: Rules are processed by priority (lowest number = highest priority)**

```
Inbound Traffic Flow:
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────┐
│   Internet  │────▶│   Subnet NSG    │────▶│    NIC NSG      │────▶│   VM    │
└─────────────┘     │  (if attached)  │     │  (if attached)  │     └─────────┘
                    └─────────────────┘     └─────────────────┘

Outbound Traffic Flow:
┌─────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌──────────┐
│     VM      │────▶│    NIC NSG      │────▶│   Subnet NSG    │────▶│ Internet │
└─────────────┘     │  (if attached)  │     │  (if attached)  │     └──────────┘
```

**Rule Processing:**
1. Rules evaluated in priority order (100 before 200)
2. First matching rule wins (Allow or Deny)
3. If no rule matches, default rules apply

### 2. Default NSG Rules

Every NSG has these immutable default rules:

**Inbound Defaults:**
| Priority | Name | Source | Destination | Action |
|----------|------|--------|-------------|--------|
| 65000 | AllowVnetInBound | VirtualNetwork | VirtualNetwork | Allow |
| 65001 | AllowAzureLoadBalancerInBound | AzureLoadBalancer | * | Allow |
| 65500 | DenyAllInBound | * | * | Deny |

**Outbound Defaults:**
| Priority | Name | Source | Destination | Action |
|----------|------|--------|-------------|--------|
| 65000 | AllowVnetOutBound | VirtualNetwork | VirtualNetwork | Allow |
| 65001 | AllowInternetOutBound | * | Internet | Allow |
| 65500 | DenyAllOutBound | * | * | Deny |

### 3. Service Tags

Azure-managed IP address groups that update automatically:

| Service Tag | Description | Common Use |
|-------------|-------------|------------|
| Internet | All public IPs | Allow/deny internet access |
| VirtualNetwork | VNet + peered VNets + on-prem via VPN | Internal traffic |
| AzureLoadBalancer | Azure's health probe source | Required for LB |
| AzureCloud | All Azure datacenter IPs | Azure service access |
| AzureCloud.EastUS | Azure IPs in specific region | Regional restrictions |
| Storage | Azure Storage IPs | Storage access rules |
| Sql | Azure SQL IPs | Database access |
| AzureActiveDirectory | Azure AD IPs | Authentication traffic |
| GatewayManager | Azure Gateway Manager | VPN/ExpressRoute mgmt |

### 4. Application Security Groups (ASGs)

ASGs allow grouping VMs by function instead of IP address.

**Without ASGs:**
```
Rule: Allow 10.1.1.4, 10.1.1.5, 10.1.1.6, 10.1.1.7 → Port 80
(Must update rule when VMs added/removed)
```

**With ASGs:**
```
Rule: Allow ASG:asg-webservers → Port 80
(VMs automatically included/excluded based on ASG membership)
```

**Benefits:**
- Rules don't need IP addresses
- Membership is dynamic (scales automatically)
- Cleaner, more maintainable rules
- Self-documenting security policies

### 5. Augmented Security Rules

Allow combining multiple sources/destinations in a single rule:

```
Single rule can specify:
- Multiple source IPs (up to 4000 per rule)
- Multiple destination IPs
- Multiple ports
- Service tags
- Application Security Groups
```

## Exercise Steps

### Step 1: Deploy the Infrastructure

```bash
cd exercises/02-network-security

chmod +x deploy.sh cleanup.sh

./deploy.sh
```

### Step 2: Verify Default Connectivity

Initially, all VMs can communicate (default VirtualNetwork rule):

```bash
# Get VM IPs from deployment output
# SSH to web VM
ssh azureuser@<web-vm-public-ip>

# From web VM, test connectivity to app VM
ping 10.1.2.4 -c 3   # Should work (same VNet)
curl 10.1.2.4:8080   # Should work if app running

# Test connectivity to DB VM  
ping 10.1.3.4 -c 3   # Should work

exit
```

### Step 3: Examine NSG Rules

```bash
# List rules for web subnet NSG
az network nsg rule list \
  --resource-group rg-learn-network-security \
  --nsg-name nsg-snet-web \
  --output table

# Include default rules
az network nsg rule list \
  --resource-group rg-learn-network-security \
  --nsg-name nsg-snet-web \
  --include-default \
  --output table
```

### Step 4: Test Security Rules

After deployment, NSG rules enforce:
- Only web tier accepts HTTP/HTTPS from internet
- Only app tier can receive from web tier
- Only db tier can receive SQL from app tier

```bash
# From your machine - test HTTP to web (should work)
curl http://<web-vm-public-ip>

# SSH to web VM and test
ssh azureuser@<web-vm-public-ip>

# From web VM, verify HTTP to app works
curl 10.1.2.4:8080

# From web VM, verify direct DB access is DENIED
nc -zv 10.1.3.4 1433  # Should timeout/fail

exit
```

### Step 5: Examine ASG Membership

```bash
# List ASG members (NICs assigned to each ASG)
az network nic list \
  --resource-group rg-learn-network-security \
  --query "[].{NIC:name, ASGs:ipConfigurations[0].applicationSecurityGroups[0].id}" \
  --output table
```

### Step 6: Test NSG Effective Rules

```bash
# Get effective security rules for a NIC
az network nic list-effective-nsg \
  --resource-group rg-learn-network-security \
  --name nic-vm-web-1 \
  --output table
```

### Step 7: Use IP Flow Verify (Network Watcher)

```bash
# Test if traffic would be allowed
az network watcher test-ip-flow \
  --resource-group rg-learn-network-security \
  --vm vm-web-1 \
  --direction Inbound \
  --local 10.1.1.4:80 \
  --remote 203.0.113.1:12345 \
  --protocol TCP
# Expected: Access=Allow, Rule=AllowHTTP

# Test denied traffic
az network watcher test-ip-flow \
  --resource-group rg-learn-network-security \
  --vm vm-web-1 \
  --direction Inbound \
  --local 10.1.1.4:22 \
  --remote 203.0.113.1:12345 \
  --protocol TCP
# Expected: Access=Deny (unless your IP matches the SSH rule)
```

## Verification Checklist

- [ ] Three subnets with separate NSGs
- [ ] Web VMs accessible via HTTP from internet
- [ ] App VMs only accessible from web VMs
- [ ] DB VM only accessible from app VMs on SQL port
- [ ] Can verify rules using IP Flow Verify
- [ ] Understand NSG rule priority ordering

## Deep Dive: The Bicep Template

Study `main.bicep` to understand:

1. **NSG definition** - Rules array with priorities
2. **Subnet-NSG association** - How NSGs attach to subnets
3. **ASG creation and assignment** - Grouping VMs logically
4. **Service tag usage** - Internet, VirtualNetwork in rules

## Cleanup

```bash
./cleanup.sh
```

## Common Issues

| Issue | Solution |
|-------|----------|
| Can't SSH to VM | Check NSG allows your IP on port 22 |
| VMs can't communicate | Verify VirtualNetwork tag in rules |
| Rules not taking effect | Check if both subnet and NIC NSG blocking |
| ASG rule not working | Verify NIC is assigned to ASG |

## What's Next?

In **Module 3: VNet Peering**, you'll:
- Connect multiple VNets
- Understand peering properties
- Configure gateway transit

## Additional Resources

- [NSG documentation](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Service tags](https://learn.microsoft.com/azure/virtual-network/service-tags-overview)
- [ASG documentation](https://learn.microsoft.com/azure/virtual-network/application-security-groups)
