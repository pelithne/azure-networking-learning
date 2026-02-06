# Module 15: ExpressRoute (Theoretical)

> ⚠️ **Note**: ExpressRoute requires physical infrastructure and carrier agreements. This module is theoretical.

## Overview

ExpressRoute provides private, dedicated connections between your on-premises network and Azure, bypassing the public internet.

## Connection Models

### 1. CloudExchange Co-location
```
Your Equipment ──── Exchange Provider ──── Microsoft Edge
                    (Equinix, etc.)
```
Best for: Data centers at carrier-neutral facilities

### 2. Point-to-Point Ethernet
```
Your Equipment ──────── Direct Fiber ──────── Microsoft Edge
```
Best for: Large enterprises with direct connectivity needs

### 3. Any-to-Any (IPVPN)
```
Branch 1 ──┐
Branch 2 ──┼─── MPLS Network ──── Microsoft Edge
Branch 3 ──┘
```
Best for: Organizations with existing MPLS networks

### 4. ExpressRoute Direct
```
Your Equipment ──── 10G/100G Direct ──── Microsoft Edge
```
Best for: Massive data transfer, highest bandwidth needs

## Peering Types

| Peering | Purpose | Accesses |
|---------|---------|----------|
| **Azure Private** | VNets | VMs, ILBs, Private Endpoints |
| **Microsoft** | Microsoft 365, Azure PaaS | Office 365, Azure Storage, SQL |

> ⚠️ Azure Public peering is deprecated. Use Microsoft peering instead.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ON-PREMISES                                  │
│                                                                     │
│  ┌───────────────┐                                                  │
│  │ Branch Office │                                                  │
│  └───────┬───────┘                                                  │
│          │                                                          │
│  ┌───────▼───────┐                                                  │
│  │  Core Router  │◄─── BGP Peering ───┐                            │
│  └───────┬───────┘                    │                            │
│          │                            │                            │
│  ┌───────▼───────┐                    │                            │
│  │   CE Router   │                    │                            │
│  │ (Customer     │                    │                            │
│  │  Edge)        │                    │                            │
│  └───────┬───────┘                    │                            │
└──────────┼────────────────────────────┼────────────────────────────┘
           │                            │
           │  Physical Connection       │ BGP Routes
           │                            │
┌──────────▼────────────────────────────▼────────────────────────────┐
│                    EXPRESSROUTE CIRCUIT                            │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Provider Edge (PE)                        │   │
│  │                    Carrier Network                           │   │
│  └─────────────────────────────┬───────────────────────────────┘   │
│                                │                                    │
│  ┌─────────────────────────────▼───────────────────────────────┐   │
│  │                    Microsoft Edge (MSEE)                     │   │
│  │                                                              │   │
│  │  ┌────────────────┐        ┌────────────────┐              │   │
│  │  │ Private Peering│        │Microsoft Peering│              │   │
│  │  │ (Azure VNets)  │        │ (M365, PaaS)   │              │   │
│  │  └────────────────┘        └────────────────┘              │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
           │                            │
           ▼                            ▼
┌──────────────────────┐     ┌──────────────────────┐
│    Azure VNets       │     │   Microsoft 365      │
│    (via Gateway)     │     │   Azure PaaS         │
└──────────────────────┘     └──────────────────────┘
```

## ExpressRoute SKUs

| SKU | Features | Use Case |
|-----|----------|----------|
| **Local** | Single region, unlimited data | Single-region workloads |
| **Standard** | Same geo, 10 VNets | Regional deployments |
| **Premium** | Global reach, 100 VNets | Enterprise/global |

## Redundancy Options

### 1. Single Circuit (Not recommended)
```
On-Prem ──── Circuit ──── Azure
         (Single point of failure)
```

### 2. Dual Circuits (Recommended)
```
On-Prem ──┬── Circuit A (Location 1) ──┬── Azure
          │                              │
          └── Circuit B (Location 2) ──┘
              (Different meet-me)
```

### 3. ExpressRoute + VPN Backup
```
On-Prem ──┬── ExpressRoute (Primary) ──┬── Azure
          │                            │
          └── Site-to-Site VPN (Backup)┘
```

## ExpressRoute Gateway SKUs

| SKU | Circuits | Bandwidth | Use Case |
|-----|----------|-----------|----------|
| Standard | 4 | 1 Gbps | Development |
| HighPerformance | 4 | 2 Gbps | Production |
| UltraPerformance | 16 | 10 Gbps | Data-intensive |
| ErGw1Az | 4 | 1 Gbps | Zone-redundant |
| ErGw2Az | 4 | 2 Gbps | Zone-redundant |
| ErGw3Az | 16 | 10 Gbps | Zone-redundant |

## Key Configuration Elements

### BGP Requirements
```
- ASN: Customer-owned or default (65515 for Azure private)
- Primary subnet: /30 for each peering
- Secondary subnet: /30 for each peering (redundancy)
- VLAN ID for each peering
```

### Example Configuration
```
Private Peering:
- Primary: 192.168.1.0/30
  - Customer: 192.168.1.1
  - Microsoft: 192.168.1.2
- Secondary: 192.168.1.4/30
  - Customer: 192.168.1.5
  - Microsoft: 192.168.1.6
- VLAN: 200
- ASN: 65001 (your ASN)
```

## FastPath

Bypasses the gateway for improved data path performance:
- Requires UltraPerformance or ErGwAz SKU
- Traffic goes directly to VMs, not through gateway
- Not supported with VNet peering or UDRs

## Global Reach

Connect on-premises sites through ExpressRoute:
```
Site A ──── ExpressRoute ──── Azure ──── ExpressRoute ──── Site B
                           (backbone)
```

## Cost Considerations

| Component | Approximate Cost |
|-----------|------------------|
| Circuit (Standard, 50 Mbps) | ~$55/month |
| Circuit (Premium, 1 Gbps) | ~$800/month |
| Gateway (Standard) | ~$150/month |
| Gateway (UltraPerformance) | ~$1,000/month |
| Data transfer (egress) | Varies by SKU |

## When to Use ExpressRoute

✅ **Good For:**
- Consistent, predictable latency requirements
- High bandwidth (>1 Gbps)
- Compliance/regulatory requirements
- Large data transfers
- Hybrid with Microsoft 365

❌ **Consider Alternatives When:**
- Budget constrained
- Variable/low bandwidth needs
- Quick setup required
- Single small office

## CLI Commands (Reference)

```bash
# Create ExpressRoute circuit
az network express-route create \
  --name "MyExpressRoute" \
  -g rg-network \
  --bandwidth 50 \
  --peering-location "Silicon Valley" \
  --provider "Equinix" \
  --sku-family MeteredData \
  --sku-tier Standard

# Get service key (provide to carrier)
az network express-route show \
  --name "MyExpressRoute" \
  -g rg-network \
  --query serviceKey

# Configure private peering
az network express-route peering create \
  --circuit-name "MyExpressRoute" \
  -g rg-network \
  --peering-type AzurePrivatePeering \
  --peer-asn 65001 \
  --primary-peer-subnet 192.168.1.0/30 \
  --secondary-peer-subnet 192.168.1.4/30 \
  --vlan-id 200
```
