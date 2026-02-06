# Module 12: Hub-Spoke Architecture

## Overview

Hub-spoke is the standard enterprise networking pattern in Azure. The hub contains shared services (firewall, bastion, gateway), and spokes contain workloads.

## Key Concepts

### Hub Contains

- Azure Firewall (centralized security)
- Azure Bastion (secure access)
- VPN/ExpressRoute Gateway (hybrid connectivity)
- Shared services (DNS, monitoring)

### Spoke Contains

- Application workloads
- Isolated by design
- Routes through hub for cross-spoke traffic

### Gateway Transit

When enabled, spokes can use the hub's VPN/ExpressRoute gateway to reach on-premises networks.

## Architecture

```
                         On-Premises
                              │
                              │ VPN/ExpressRoute
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         HUB VNET                            │
│                        10.0.0.0/16                          │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Bastion   │  │  Firewall   │  │   Gateway Subnet    │  │
│  │  /26        │  │  /26        │  │   /27               │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │               Shared Services Subnet                    ││
│  │               (DNS, AD, etc.)                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
   ┌────────────┐  ┌────────────┐  ┌────────────┐
   │  SPOKE A   │  │  SPOKE B   │  │  SPOKE C   │
   │ Web Tier   │  │ App Tier   │  │ Data Tier  │
   │ 10.1.0.0   │  │ 10.2.0.0   │  │ 10.3.0.0   │
   └────────────┘  └────────────┘  └────────────┘
```

## Traffic Flows

| From | To | Path |
|------|-----|------|
| Spoke A | Internet | Spoke A → Firewall → Internet |
| Spoke A | Spoke B | Spoke A → Firewall → Spoke B |
| Spoke A | On-Prem | Spoke A → Gateway → On-Prem |
| Internet | Spoke A | Internet → Firewall → Spoke A |

## Deployment

```bash
cd exercises/12-hub-spoke
./deploy.sh
```

> ⚠️ This deploys multiple resources. Cost: ~$2-3/hour

## Key Configurations

1. **Peering**: Hub ↔ each spoke (not spoke-to-spoke)
2. **Route Tables**: Force 0.0.0.0/0 → Firewall
3. **Gateway Transit**: Allow spokes to use hub gateway
4. **Firewall Rules**: Control all traffic flows
