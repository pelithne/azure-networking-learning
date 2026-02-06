# Module 10: Routing & User Defined Routes (UDRs)

## Overview

Azure routes traffic based on system routes by default. UDRs let you override this behavior to force traffic through Network Virtual Appliances (NVAs), firewalls, or specific paths.

## Key Concepts

### System Routes (Default)

Azure automatically creates routes for:
- VNet address space (local delivery)
- Peered VNets
- VPN/ExpressRoute gateways
- 0.0.0.0/0 → Internet

### Next Hop Types

| Type | Description |
|------|-------------|
| **VirtualNetworkGateway** | Send to VPN/ExpressRoute gateway |
| **VnetLocal** | Deliver within VNet |
| **Internet** | Route to internet |
| **VirtualAppliance** | Send to NVA IP address |
| **None** | Drop packets (blackhole) |

### Route Priority

1. User Defined Routes (UDRs)
2. BGP routes (from gateways)
3. System routes

More specific prefix wins (longest prefix match).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         Hub VNet                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │              NVA (vm-nva)                       │    │
│  │              10.0.1.4                           │    │
│  │              IP Forwarding: ENABLED             │    │
│  └─────────────────────────────────────────────────┘    │
│                           │                              │
│                    Traffic Flows                         │
└───────────────────────────┼──────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                                       ▼
┌───────────────┐                       ┌───────────────┐
│   Spoke VNet A │                       │   Spoke VNet B │
│   10.1.0.0/16  │                       │   10.2.0.0/16  │
│                │                       │                │
│ Route Table:   │                       │ Route Table:   │
│ 10.2.0.0/16    │                       │ 10.1.0.0/16    │
│ → 10.0.1.4 NVA │                       │ → 10.0.1.4 NVA │
└───────────────┘                       └───────────────┘
```

## Deployment

```bash
cd exercises/10-routing-udr
./deploy.sh
```

## Test Commands

```bash
# Test routing through NVA
# From VM-A, traceroute to VM-B shows NVA as hop
traceroute 10.2.1.4  # Should show 10.0.1.4 (NVA) as intermediate hop
```

## Notes

For an NVA to forward traffic:
1. **IP Forwarding** must be enabled on the NIC in Azure
2. **OS-level forwarding** must be enabled (sysctl net.ipv4.ip_forward=1)
