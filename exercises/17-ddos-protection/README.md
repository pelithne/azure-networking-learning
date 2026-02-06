# Module 17: DDoS Protection (Theoretical)

> ⚠️ **Note**: DDoS Protection Standard costs ~$2,944/month. This module is theoretical.

## Overview

Azure DDoS Protection defends your Azure resources against Distributed Denial of Service attacks.

## Protection Tiers

### DDoS Infrastructure Protection (Free)
- Automatic, always-on
- Protects all Azure services
- Basic L3/L4 protection
- No configuration needed

### DDoS Network Protection (~$2,944/month)
- Enhanced mitigation
- Attack metrics and alerting
- DDoS Rapid Response team access
- Cost protection guarantee
- Application level telemetry

### DDoS IP Protection (~$199/month per IP)
- Per-IP protection
- Same features as Network Protection
- Good for smaller deployments

## How DDoS Protection Works

```
                          Attack Traffic
                               │
                               │
                    ┌──────────▼──────────┐
                    │                      │
                    │   Azure Edge         │
                    │   (Scrubbing Center) │
                    │                      │
                    │   ┌──────────────┐   │
                    │   │ Detection    │   │
                    │   │ & Mitigation │   │
                    │   └──────────────┘   │
                    │                      │
                    └──────────┬──────────┘
                               │
                         Clean Traffic
                               │
                    ┌──────────▼──────────┐
                    │                      │
                    │   Your Azure VNet    │
                    │                      │
                    │   ┌────────────────┐ │
                    │   │ Application    │ │
                    │   │ Gateway / LB   │ │
                    │   └────────────────┘ │
                    │                      │
                    └─────────────────────┘
```

## Attack Types Mitigated

### Volumetric Attacks
- **UDP Flood**: Overwhelm with UDP packets
- **ICMP Flood**: Ping flood
- **Amplification**: DNS, NTP, SSDP reflection

### Protocol Attacks
- **SYN Flood**: Exhaust connection state
- **Fragmented Packets**: Overwhelm reassembly
- **Smurf Attack**: ICMP to broadcast address

### Application Layer Attacks
- **HTTP Flood**: Overwhelm web server
- **Slowloris**: Hold connections open
- Requires WAF (App Gateway + WAF or Front Door + WAF)

## DDoS Protection Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Subscription                                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              DDoS Protection Plan                        │   │
│  │     (Protects up to 100 VNets in the subscription)      │   │
│  └───────────────────────────┬─────────────────────────────┘   │
│                              │                                  │
│              ┌───────────────┼───────────────┐                  │
│              │               │               │                  │
│              ▼               ▼               ▼                  │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐       │
│  │  VNet-1       │  │  VNet-2       │  │  VNet-3       │       │
│  │  (Protected)  │  │  (Protected)  │  │  (Protected)  │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Metrics

| Metric | Description |
|--------|-------------|
| Inbound packets dropped | Packets dropped by DDoS |
| Inbound packets forwarded | Clean packets allowed |
| Under DDoS attack | Boolean - attack in progress |
| Inbound TCP packets | TCP received |
| Inbound UDP packets | UDP received |

## Alerts Configuration

```
┌─────────────────────────────────────────────────────────────────┐
│                     Alert Rules                                 │
├─────────────────────────────────────────────────────────────────┤
│ Rule 1: DDoS Attack Started                                     │
│   Condition: "Under DDoS attack" = True                        │
│   Action: Email, SMS, Call Rapid Response                      │
├─────────────────────────────────────────────────────────────────┤
│ Rule 2: DDoS Attack Ended                                       │
│   Condition: "Under DDoS attack" = False                       │
│   Action: Email notification                                    │
├─────────────────────────────────────────────────────────────────┤
│ Rule 3: High Traffic Volume                                     │
│   Condition: Inbound packets > threshold                        │
│   Action: Email, Webhook                                        │
└─────────────────────────────────────────────────────────────────┘
```

## DDoS Rapid Response (DRR)

Available with DDoS Protection Standard:
- Engage during active attack
- Attack analysis
- Post-attack report
- Best practice recommendations

Contact methods:
1. Azure support ticket
2. Open case during attack

## Cost Protection

DDoS Protection Standard includes:
- Credit for scale-out costs during attack
- Covers: App Gateway, VM, Load Balancer, AKS costs
- Must be documented DDoS attack
- Fill cost protection form within 30 days

## Best Practices

### 1. Layer Defense
```
Internet ──► DDoS Protection ──► Azure Firewall ──► App Gateway WAF ──► Apps
             (L3/L4)            (L4)               (L7)
```

### 2. Use Standard Load Balancer
Standard LB is DDoS aware - distributes attack traffic

### 3. Deploy Behind Public IPs
DDoS protects resources with public IPs:
- Public Load Balancers
- Application Gateway
- VM public IPs
- Firewall public IP

### 4. Limit Public Endpoints
- Use Private Endpoints where possible
- Fewer public IPs = smaller attack surface

## CLI Commands (Reference)

```bash
# Create DDoS Protection Plan
az network ddos-protection create \
  --name "ddos-plan" \
  -g rg-network

# Associate VNet with DDoS Plan
az network vnet update \
  --name "vnet-main" \
  -g rg-network \
  --ddos-protection-plan "/subscriptions/.../ddos-plan"

# Check DDoS metrics
az monitor metrics list \
  --resource "/subscriptions/.../publicIPAddresses/pip-appgw" \
  --metric "IfUnderDDoSAttack" \
  --interval PT1M
```

## When to Use DDoS Protection Standard

✅ **Consider When:**
- Internet-facing critical applications
- SLA requirements for availability
- Compliance/regulatory needs
- Large attack surface (many public IPs)
- Need rapid response support

❌ **Basic Protection May Suffice When:**
- Internal-only applications
- Small/non-critical workloads
- Budget constraints
- Few public endpoints

## Comparison Table

| Feature | Basic | Standard | IP Protection |
|---------|-------|----------|---------------|
| Cost | Free | ~$2,944/mo | ~$199/mo per IP |
| L3/L4 Protection | ✅ | ✅ | ✅ |
| Adaptive Tuning | ❌ | ✅ | ✅ |
| Attack Metrics | ❌ | ✅ | ✅ |
| Alerts | ❌ | ✅ | ✅ |
| DDoS Rapid Response | ❌ | ✅ | ✅ |
| Cost Protection | ❌ | ✅ | ❌ |
| WAF Integration | ❌ | ✅ | ✅ |
| VNets Protected | N/A | 100 | Per IP |
