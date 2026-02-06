# Module 16: Virtual WAN (Theoretical)

> ⚠️ **Note**: Virtual WAN has significant costs (~$0.05/hour per hub). This module is primarily theoretical.

## Overview

Azure Virtual WAN is a networking service that brings together VPN, ExpressRoute, and branch connectivity into a single operational interface.

## Traditional vs Virtual WAN

### Traditional Hub-Spoke
```
           ┌─── Spoke A
           │
Hub ───────┼─── Spoke B
(You manage)│
           └─── Spoke C

- You deploy and manage firewall
- You configure all peerings
- You manage routing
- You set up VPN gateway
```

### Virtual WAN
```
           ┌─── Spoke A
           │
vWAN Hub ──┼─── Spoke B
(Microsoft │
 managed)  └─── Spoke C

- Microsoft manages hub infrastructure
- Automatic any-to-any connectivity
- Integrated VPN, ER, P2S
- Managed routing
```

## Virtual WAN Types

| Type | Hub Features |
|------|--------------|
| **Basic** | Site-to-Site VPN only |
| **Standard** | ExpressRoute, P2S VPN, VNet, Inter-hub |

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          AZURE VIRTUAL WAN                           │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                      Virtual WAN Resource                       │  │
│  │                        (Global object)                          │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│     ┌─────────────────┐           ┌─────────────────┐               │
│     │   Virtual Hub   │◄─────────►│   Virtual Hub   │               │
│     │   West US       │   Azure   │   East US       │               │
│     │                 │  Backbone │                 │               │
│     │ ┌─────────────┐ │           │ ┌─────────────┐ │               │
│     │ │S2S VPN      │ │           │ │ExpressRoute │ │               │
│     │ │Gateway      │ │           │ │Gateway      │ │               │
│     │ └─────────────┘ │           │ └─────────────┘ │               │
│     │ ┌─────────────┐ │           │ ┌─────────────┐ │               │
│     │ │P2S VPN      │ │           │ │Azure        │ │               │
│     │ │Gateway      │ │           │ │Firewall     │ │               │
│     │ └─────────────┘ │           │ └─────────────┘ │               │
│     └────────┬────────┘           └────────┬────────┘               │
│              │                              │                        │
└──────────────┼──────────────────────────────┼────────────────────────┘
               │                              │
      ┌────────┼────────┐            ┌────────┼────────┐
      ▼        ▼        ▼            ▼        ▼        ▼
  ┌──────┐ ┌──────┐ ┌──────┐    ┌──────┐ ┌──────┐ ┌──────┐
  │VNet  │ │VNet  │ │Branch│    │VNet  │ │VNet  │ │Branch│
  │Spoke1│ │Spoke2│ │Office│    │Spoke3│ │Spoke4│ │Office│
  └──────┘ └──────┘ └──────┘    └──────┘ └──────┘ └──────┘
```

## Virtual Hub Components

| Component | Purpose |
|-----------|---------|
| **Hub VNet** | Microsoft-managed VNet (automatically created) |
| **VPN Gateway** | Site-to-site and point-to-site VPN |
| **ExpressRoute Gateway** | ExpressRoute circuit connections |
| **Azure Firewall** | Centralized security (Secured Hub) |
| **Route Tables** | Routing intent and policies |

## Connectivity Scenarios

### Any-to-Any (Default)
All spokes can communicate with each other automatically.

### Isolated Spokes
Use route tables to prevent spoke-to-spoke communication.

### Secured Hub (with Firewall)
```
Spoke A ──► Azure Firewall ──► Spoke B
            (in hub)

All inter-spoke and internet traffic inspected
```

## Routing

### Routing Intent
Simplifies configuration by defining traffic destinations:

```
Routing Intent:
├── Internet Traffic: → Azure Firewall
└── Private Traffic:  → Azure Firewall
```

### Custom Route Tables
```
┌─────────────────────────────────────────────┐
│ Route Table: RT_ISOLATED                    │
├─────────────────────────────────────────────┤
│ Associated: Spoke1, Spoke2                  │
│ Propagating: None                           │
│ Routes:                                     │
│   0.0.0.0/0 → Azure Firewall               │
│   (No routes to other spokes)              │
└─────────────────────────────────────────────┘
```

## Virtual WAN + NVA

You can deploy Network Virtual Appliances (NVAs) in the hub:
- Barracuda
- Check Point
- Cisco
- Fortinet
- Palo Alto
- And others

```
Branch ──► VPN Gateway ──► NVA ──► Spoke VNets
                      (inspection)
```

## SD-WAN Integration

Virtual WAN integrates with SD-WAN solutions:
```
Branch ──► SD-WAN CPE ──► Azure VWAN ──► Azure VNets
           (auto-configured)
```

Supported vendors:
- Cisco Viptela
- VMware SD-WAN
- Citrix SD-WAN
- Fortinet
- And others

## Cost Considerations

| Component | Approximate Cost |
|-----------|------------------|
| Virtual WAN (resource) | Free |
| Virtual Hub | ~$0.05/hour (~$36/month) |
| VPN Gateway (S2S) | ~$0.361/hour |
| VPN Gateway (P2S) | ~$0.013/hour per connection |
| ExpressRoute Gateway | ~$0.42/hour |
| Data transfer | Standard Azure rates |

## When to Use Virtual WAN

✅ **Good For:**
- Large enterprises with many branches
- Global presence requiring multi-hub
- Simplified management at scale
- SD-WAN integration
- Any-to-any connectivity needs

❌ **Consider Traditional Hub-Spoke When:**
- Single region deployment
- Need custom NVA in hub (limited support in vWAN)
- Cost-sensitive (vWAN adds overhead)
- Simple topology with few connections
- Need fine-grained routing control

## CLI Commands (Reference)

```bash
# Create Virtual WAN
az network vwan create \
  --name "MyVirtualWAN" \
  -g rg-network \
  --type Standard

# Create Virtual Hub
az network vhub create \
  --name "hub-westus" \
  -g rg-network \
  --vwan "MyVirtualWAN" \
  --location westus \
  --address-prefix 10.0.0.0/24

# Create VPN Gateway in Hub
az network vpn-gateway create \
  --name "vpn-hub-westus" \
  -g rg-network \
  --vhub "hub-westus" \
  --location westus

# Connect VNet to Hub
az network vhub connection create \
  --name "conn-spoke1" \
  -g rg-network \
  --vhub-name "hub-westus" \
  --remote-vnet "/subscriptions/.../virtualNetworks/vnet-spoke1"
```

## Lab Exercise (Optional - High Cost)

If you want to deploy Virtual WAN, be aware:
- Deployment takes 30+ minutes
- Costs ~$2-5/hour with all components
- Creates multiple resources

```bash
# Only if you want to try it (expensive!)
cd exercises/16-virtual-wan
./deploy.sh  # Optional lab deployment
```
