# Module 6: Azure Load Balancer

## Overview

Azure Load Balancer is a Layer 4 (TCP/UDP) load balancer that distributes traffic across healthy backend instances. This module covers both public and internal load balancers, health probes, and outbound connectivity.

## Learning Objectives

By completing this exercise, you will:

1. **Understand L4 load balancing** - TCP/UDP distribution concepts
2. **Deploy Public Load Balancer** - Internet-facing traffic distribution
3. **Deploy Internal Load Balancer** - Private traffic distribution
4. **Configure health probes** - Backend health monitoring
5. **Understand SNAT** - Outbound connectivity and port exhaustion
6. **Configure outbound rules** - Explicit outbound NAT

## Prerequisites

- Completed Modules 1-3
- Basic understanding of TCP/IP

## Architecture

```
                            INTERNET
                                │
                                ▼
                        ┌───────────────┐
                        │  Public IP    │
                        │  20.x.x.x     │
                        └───────┬───────┘
                                │
                    ┌───────────┴───────────┐
                    │   PUBLIC LOAD         │
                    │   BALANCER            │
                    │                       │
                    │ LB Rule: 80 → 80      │
                    │ Health: TCP 80        │
                    └───────────┬───────────┘
                                │
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
    ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
    │   vm-web-1    │   │   vm-web-2    │   │   vm-web-3    │
    │   10.0.1.4    │   │   10.0.1.5    │   │   10.0.1.6    │
    │   (nginx)     │   │   (nginx)     │   │   (nginx)     │
    └───────────────┘   └───────────────┘   └───────────────┘
            │                   │                   │
            └───────────────────┼───────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │  INTERNAL LOAD        │
                    │  BALANCER             │
                    │  10.0.2.100           │
                    │                       │
                    │  LB Rule: 8080 → 8080 │
                    └───────────┬───────────┘
                                │
            ┌───────────────────┴───────────────────┐
            ▼                                       ▼
    ┌───────────────┐                       ┌───────────────┐
    │   vm-app-1    │                       │   vm-app-2    │
    │   10.0.2.4    │                       │   10.0.2.5    │
    └───────────────┘                       └───────────────┘
```

## Key Networking Concepts

### 1. Load Balancer SKUs

| Feature | Basic | Standard |
|---------|-------|----------|
| Backend pool size | Up to 300 | Up to 1000 |
| Health probes | TCP, HTTP | TCP, HTTP, HTTPS |
| Availability Zones | No | Yes (zone-redundant) |
| Secure by default | No (open) | Yes (closed, needs NSG) |
| Multiple frontends | No | Yes |
| Outbound rules | No | Yes |
| SLA | No | 99.99% |
| Global LB | No | Yes (cross-region) |
| **Recommendation** | Dev/Test only | Production |

> ⚠️ **Important**: Basic SKU is being retired. Always use Standard SKU.

### 2. Load Balancer Components

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCER COMPONENTS                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  FRONTEND IP CONFIGURATION                                          │
│  └── Public IP (external LB) or Private IP (internal LB)           │
│  └── Can have multiple frontends                                    │
│                                                                      │
│  BACKEND POOL                                                        │
│  └── Collection of VMs/VMSSs/IPs to receive traffic               │
│  └── NIC-based or IP-based (IP allows external targets)            │
│                                                                      │
│  HEALTH PROBE                                                        │
│  └── Determines if backend is healthy                               │
│  └── TCP, HTTP, or HTTPS                                            │
│  └── Configurable interval and threshold                            │
│                                                                      │
│  LOAD BALANCING RULE                                                 │
│  └── Maps frontend port to backend port                             │
│  └── Links frontend, backend pool, and health probe                │
│  └── Session persistence options                                    │
│                                                                      │
│  OUTBOUND RULE (Optional)                                           │
│  └── Explicit SNAT configuration                                    │
│  └── Controls outbound connectivity                                 │
│                                                                      │
│  INBOUND NAT RULE (Optional)                                        │
│  └── Direct traffic to specific VM                                  │
│  └── Useful for SSH/RDP to individual VMs                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 3. Load Distribution Algorithms

| Mode | Description | Use Case |
|------|-------------|----------|
| **5-tuple hash** (default) | Source IP, Source Port, Dest IP, Dest Port, Protocol | General purpose |
| **Source IP affinity** (2-tuple) | Source IP, Dest IP | Stateful apps |
| **Source IP + Protocol** (3-tuple) | Source IP, Dest IP, Protocol | Complex scenarios |

### 4. Health Probe Types

| Type | Port | Path | Use Case |
|------|------|------|----------|
| **TCP** | Required | N/A | Any TCP service |
| **HTTP** | Required | Required | Web servers (checks HTTP 200) |
| **HTTPS** | Required | Required | Secure web servers |

**Health Probe Parameters:**
- **Interval**: Time between probes (5-30 seconds)
- **Unhealthy threshold**: Failed probes before marking unhealthy (2-10)
- **Probe port** can differ from service port

### 5. SNAT and Outbound Connectivity

```
OUTBOUND FLOW (VM initiating connection to internet):

              Standard LB              NAT Gateway        Default Outbound
              with Outbound Rule       (Recommended)      (Deprecated)
                    │                       │                   │
                    ▼                       ▼                   │
┌─────────────────────────────────────────────────────────────────────┐
│  VM 10.0.1.4 wants to reach api.example.com                         │
│                                                                     │
│  Option 1: LB Outbound Rule                                        │
│  └── Uses LB frontend IP for SNAT                                  │
│  └── Pre-allocated port pool (configurable)                        │
│  └── Risk of SNAT port exhaustion under load                       │
│                                                                     │
│  Option 2: NAT Gateway (BEST)                                       │
│  └── Dedicated outbound service                                     │
│  └── 64,000 SNAT ports per IP                                      │
│  └── Scales automatically                                           │
│                                                                     │
│  Option 3: Public IP on VM                                          │
│  └── Direct internet access                                         │
│  └── No SNAT needed                                                 │
│                                                                     │
│  Default Outbound Access                                            │
│  └── Being RETIRED - don't rely on it!                             │
└─────────────────────────────────────────────────────────────────────┘
```

### 6. HA Ports (High Availability Ports)

For internal load balancers, HA Ports enables load balancing on ALL ports:

```bicep
loadBalancingRule: {
  protocol: 'All'      // TCP + UDP
  frontendPort: 0      // All ports
  backendPort: 0       // All ports
  enableFloatingIP: true
}
```

**Use Cases:**
- Network Virtual Appliances (firewalls)
- SQL AlwaysOn clusters
- Any service requiring all-port access

## Exercise Steps

### Step 1: Deploy the Infrastructure

```bash
cd exercises/06-load-balancer

chmod +x deploy.sh cleanup.sh

./deploy.sh
```

### Step 2: Test Public Load Balancer

```bash
# Get the public IP
PUBLIC_IP=$(az network public-ip show \
  --resource-group rg-learn-load-balancer \
  --name pip-lb-public \
  --query ipAddress -o tsv)

# Test load balancing (run multiple times)
for i in {1..10}; do
  curl -s http://$PUBLIC_IP
  echo ""
done

# You should see responses from different VMs
# "Hello from vm-web-1", "Hello from vm-web-2", etc.
```

### Step 3: Observe Health Probes

```bash
# Stop the web server on one VM
az vm run-command invoke \
  --resource-group rg-learn-load-balancer \
  --name vm-web-1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl stop nginx"

# Wait 15-20 seconds for health probe to detect

# Test again - vm-web-1 should not receive traffic
for i in {1..10}; do
  curl -s http://$PUBLIC_IP
done

# Restart the web server
az vm run-command invoke \
  --resource-group rg-learn-load-balancer \
  --name vm-web-1 \
  --command-id RunShellScript \
  --scripts "sudo systemctl start nginx"
```

### Step 4: View Backend Pool Health

```bash
# Check backend health via metrics
az monitor metrics list \
  --resource $(az network lb show -g rg-learn-load-balancer -n lb-public --query id -o tsv) \
  --metric "HealthProbeStatus" \
  --interval PT1M
```

### Step 5: Test Internal Load Balancer

```bash
# SSH to a web VM (use NAT rule)
ssh -p 50001 azureuser@$PUBLIC_IP

# From the web VM, test internal LB
curl http://10.0.2.100:8080

# Run multiple times to see distribution
for i in {1..5}; do
  curl -s http://10.0.2.100:8080
done

exit
```

### Step 6: Examine Session Persistence

```bash
# Default: 5-tuple hash (no persistence)
# Each request may go to different backend

# With session persistence enabled, same client → same backend
# Check the LB rule configuration:
az network lb rule show \
  --resource-group rg-learn-load-balancer \
  --lb-name lb-public \
  --name http-rule \
  --query loadDistribution
```

### Step 7: Test Outbound Connectivity

```bash
# SSH to a backend VM
ssh -p 50001 azureuser@$PUBLIC_IP

# Check outbound IP (should be LB IP due to outbound rule)
curl -s ifconfig.me
echo ""

# This should match the LB public IP
# Demonstrating SNAT through the load balancer

exit
```

## Verification Checklist

- [ ] Public LB distributes traffic across web VMs
- [ ] Health probe removes unhealthy VM from rotation
- [ ] Unhealthy VM rejoins after recovery
- [ ] Internal LB accessible from web tier
- [ ] Outbound connectivity uses LB SNAT
- [ ] Can SSH to VMs using NAT rules

## Deep Dive: The Bicep Template

Study `main.bicep` to understand:

1. **Frontend IP configuration** - Public vs private
2. **Backend pool** - NIC association
3. **Health probe** - TCP vs HTTP settings
4. **Load balancing rule** - Port mapping and distribution
5. **Outbound rule** - SNAT port allocation
6. **Inbound NAT rule** - Per-VM access

## Cleanup

```bash
./cleanup.sh
```

## Common Issues

| Issue | Solution |
|-------|----------|
| No response from LB | Check NSG allows traffic on LB ports |
| All traffic to one VM | Check 5-tuple vs session persistence |
| VMs can't reach internet | Configure outbound rule or NAT Gateway |
| Health probe failing | Verify probe port/path matches service |

## What's Next?

In **Module 7: Application Gateway**, you'll:
- Deploy L7 (HTTP/HTTPS) load balancer
- Configure SSL termination
- Implement URL-based routing
- Enable Web Application Firewall

## Additional Resources

- [Azure Load Balancer documentation](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview)
- [Health probes](https://learn.microsoft.com/azure/load-balancer/load-balancer-custom-probe-overview)
- [Outbound connectivity](https://learn.microsoft.com/azure/load-balancer/load-balancer-outbound-connections)
