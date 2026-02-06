# Module 14: Network Monitoring & Diagnostics

## Overview

Network Watcher provides monitoring, diagnostics, and analytics for Azure networking.

## Network Watcher Tools

### Diagnostic Tools

| Tool | Purpose |
|------|---------|
| **IP Flow Verify** | Check if packet is allowed/denied by NSGs |
| **Next Hop** | Determine routing path for traffic |
| **Connection Troubleshoot** | Test connectivity between resources |
| **Packet Capture** | Capture packets on VMs |
| **VPN Troubleshoot** | Diagnose VPN gateway issues |

### Monitoring Tools

| Tool | Purpose |
|------|---------|
| **NSG Flow Logs** | Log all traffic through NSGs |
| **Connection Monitor** | Ongoing connectivity monitoring |
| **Traffic Analytics** | Insights from flow logs |
| **Topology** | Visual network diagram |

## NSG Flow Logs

Flow logs capture:
- Source/destination IP
- Source/destination port
- Protocol
- Allow/Deny decision
- Bytes/packets (v2)

```
┌─────────────────────────────────────────────────────────────┐
│                    NSG Flow Logs Pipeline                   │
│                                                             │
│   NSG                                                       │
│    │                                                        │
│    ▼                                                        │
│ ┌──────────┐    ┌───────────────┐    ┌──────────────────┐  │
│ │Flow Logs │───▶│Storage Account│───▶│Traffic Analytics │  │
│ │ (JSON)   │    │               │    │ (Log Analytics)  │  │
│ └──────────┘    └───────────────┘    └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Deployment

```bash
cd exercises/14-network-monitoring
./deploy.sh
```

## Common Diagnostics

### IP Flow Verify
```bash
# Check if SSH is allowed to VM
az network watcher test-ip-flow \
  --direction Inbound \
  --protocol TCP \
  --local 10.0.1.4:22 \
  --remote 203.0.113.5:50000 \
  --vm vm-test \
  -g rg-learn-monitoring
```

### Next Hop
```bash
# Where does traffic to 8.8.8.8 go?
az network watcher show-next-hop \
  --source-ip 10.0.1.4 \
  --dest-ip 8.8.8.8 \
  --vm vm-test \
  -g rg-learn-monitoring
```

### Connection Troubleshoot
```bash
# Test connectivity to external endpoint
az network watcher test-connectivity \
  --source-resource vm-test \
  --dest-address www.microsoft.com \
  --dest-port 443 \
  -g rg-learn-monitoring
```
