# Module 9: Azure Firewall

## Overview

Azure Firewall is a managed, cloud-based network security service that protects your Azure VNet resources. It provides stateful packet inspection made easy.

## Key Concepts

### Firebase Rule Types (Processed in Order)

1. **DNAT Rules** - Inbound NAT (expose internal services)
2. **Network Rules** - L3/L4 (IP/port based)
3. **Application Rules** - L7 (FQDN/URL based)

### Firewall SKUs

| SKU | Features | Cost |
|-----|----------|------|
| **Standard** | L3-L7, threat intelligence | ~$900/mo |
| **Premium** | + TLS inspection, IDPS, URL filtering | ~$1800/mo |
| **Basic** | Essential features, small workloads | ~$250/mo |

### Subnet Requirements

- Name: **AzureFirewallSubnet** (exact)
- Minimum size: /26

## Architecture

```
                    Internet
                        │
                        ▼
              ┌─────────────────┐
              │  Azure Firewall │
              │  10.0.0.4       │
              │                 │
              │  Rules:         │
              │  - Allow HTTPS  │
              │  - Block HTTP   │
              │  - Allow DNS    │
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │ Spoke 1 │   │ Spoke 2 │   │ Spoke 3 │
   └─────────┘   └─────────┘   └─────────┘
```

### User Defined Routes

To force traffic through firewall:

```
Route Table on spoke subnets:
  0.0.0.0/0 → Firewall Private IP (10.0.0.4)
```

## Deployment

```bash
cd exercises/09-azure-firewall
./deploy.sh
```

> ⚠️ Azure Firewall costs ~$1/hour. Delete when done!

## Test Commands

```bash
# From spoke VM, test outbound (goes through firewall)
curl https://www.microsoft.com  # Allowed
curl http://www.microsoft.com   # Blocked (if rule set)
```
