# Module 7: Application Gateway

## Overview

Azure Application Gateway is a Layer 7 (HTTP/HTTPS) load balancer that provides advanced routing, SSL termination, and Web Application Firewall (WAF) capabilities.

## Learning Objectives

1. **Understand L7 load balancing** - HTTP/HTTPS routing vs L4
2. **Configure SSL termination** - Certificate management
3. **Implement URL-based routing** - Path and host-based rules
4. **Enable WAF** - Protect against OWASP threats
5. **Configure health probes** - HTTP-aware health checks

## Architecture

```
                            INTERNET
                                │
                    ┌───────────┴───────────┐
                    │   APPLICATION         │
                    │   GATEWAY             │
                    │   (WAF_v2 SKU)        │
                    │                       │
                    │ Listener: HTTPS:443   │
                    │ SSL Termination       │
                    │                       │
                    │ Routing Rules:        │
                    │ /api/* → backend-api  │
                    │ /images/* → backend-static│
                    │ /* → backend-web      │
                    └───────────┬───────────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         ▼                      ▼                      ▼
 ┌───────────────┐     ┌───────────────┐     ┌───────────────┐
 │  Backend Pool │     │  Backend Pool │     │  Backend Pool │
 │  (Web)        │     │  (API)        │     │  (Static)     │
 │  vm-web-1,2   │     │  vm-api-1,2   │     │  Storage      │
 └───────────────┘     └───────────────┘     └───────────────┘
```

## Key Concepts

### Application Gateway vs Load Balancer

| Feature | App Gateway (L7) | Load Balancer (L4) |
|---------|------------------|-------------------|
| Protocol | HTTP/HTTPS | TCP/UDP |
| SSL Termination | Yes | No |
| URL Routing | Yes | No |
| WAF | Yes | No |
| Session Affinity | Cookie-based | IP-based |
| Rewrite Headers | Yes | No |

### Gateway Components

- **Frontend IP**: Public or private entry point
- **Listener**: Protocol, port, optional hostname
- **Backend Pool**: Target servers
- **HTTP Settings**: Protocol to backend, timeouts, probes
- **Rules**: Link listener → backend via routing decisions
- **Health Probes**: Custom HTTP health checks

### Subnet Requirements

- Dedicated subnet (no other resources)
- Minimum size: /24 recommended
- Name: Any (not special like GatewaySubnet)

## Deployment

```bash
cd exercises/07-app-gateway
./deploy.sh
```

> ⏱️ Application Gateway takes ~10-15 minutes to deploy.

## Cleanup

```bash
./cleanup.sh
```
