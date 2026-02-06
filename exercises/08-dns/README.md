# Module 8: DNS & Name Resolution

## Overview

This module covers Azure DNS for both public domains and private name resolution within VNets using Private DNS Zones.

## Key Concepts

### Azure DNS Services

| Service | Purpose | Use Case |
|---------|---------|----------|
| **Azure DNS** | Public domain hosting | Host your domain (example.com) |
| **Private DNS Zone** | Internal name resolution | VNet name resolution |
| **DNS Private Resolver** | Hybrid DNS | Forward queries to/from on-prem |

### Private DNS Zone Resolution

```
VM in VNet → Azure DNS (168.63.129.16) → Private DNS Zone → A Record → IP
```

### Auto-Registration

When enabled on VNet link:
- VMs automatically register in the zone
- Format: `vmname.privatezonename`
- A and PTR records created

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Private DNS Zone                                  │
│                     contoso.internal                                     │
│                                                                         │
│  Records:                                                               │
│    vm-web.contoso.internal    → 10.0.1.4                               │
│    vm-app.contoso.internal    → 10.0.2.4                               │
│    db.contoso.internal        → 10.0.3.4                               │
│                                                                         │
│  VNet Links:                                                            │
│    ├── vnet-prod (auto-registration: enabled)                          │
│    └── vnet-dev (auto-registration: disabled)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Deployment

```bash
cd exercises/08-dns
./deploy.sh
```

## Test Commands

```bash
# From VM, test private DNS resolution
nslookup vm-web.contoso.internal

# Check DNS records
az network private-dns record-set list -g rg-learn-dns -z contoso.internal -o table
```
