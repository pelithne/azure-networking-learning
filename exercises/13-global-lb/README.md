# Module 13: Global Load Balancing

## Overview

Azure provides two global load balancing services:
- **Traffic Manager** - DNS-based routing
- **Azure Front Door** - Application layer (L7) with anycast

## Traffic Manager vs Front Door

| Feature | Traffic Manager | Front Door |
|---------|-----------------|------------|
| **Layer** | DNS (returns endpoint IP) | HTTP/HTTPS (proxies traffic) |
| **Protocol** | Any (TCP/UDP) | HTTP/HTTPS only |
| **Caching** | No | Yes (CDN built-in) |
| **WAF** | No | Yes |
| **SSL Offload** | No | Yes |
| **Latency** | DNS TTL delays | Near-instant (anycast) |

## Traffic Manager Routing Methods

1. **Priority** - Active/standby failover
2. **Weighted** - Distribute % to endpoints
3. **Performance** - Route to closest (lowest latency)
4. **Geographic** - Route by user's geo location
5. **MultiValue** - Return multiple healthy endpoints
6. **Subnet** - Map IP ranges to endpoints

## Azure Front Door

```
                    Users Worldwide
                    │    │    │
        ┌───────────┘    │    └───────────┐
        ▼                ▼                ▼
   ┌─────────┐      ┌─────────┐      ┌─────────┐
   │  POP    │      │  POP    │      │  POP    │
   │ Europe  │      │  US     │      │  Asia   │
   └────┬────┘      └────┬────┘      └────┬────┘
        │                │                │
        └────────────────┼────────────────┘
                         │
                    Azure Backbone
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
       ┌────────┐   ┌────────┐   ┌────────┐
       │ Origin │   │ Origin │   │ Origin │
       │ West US│   │East US │   │ Europe │
       └────────┘   └────────┘   └────────┘
```

## Deployment

```bash
cd exercises/13-global-lb
./deploy.sh
```

## Test

```bash
# Traffic Manager - DNS lookup
nslookup <profile-name>.trafficmanager.net

# Front Door
curl https://<frontend-name>.azurefd.net
```

## Considerations

- **Traffic Manager**: Good for non-HTTP or when you need DNS-level control
- **Front Door**: Best for web apps needing CDN, WAF, and low latency
