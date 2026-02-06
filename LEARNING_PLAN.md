# Azure Networking Learning Plan

> **Goal:** Achieve expert-level understanding of Azure networking through hands-on exercises
> **Approach:** Deploy real resources using Bicep and Azure CLI with detailed explanations
> **Prerequisites:** Azure subscription, Azure CLI installed, basic Azure experience

---

## Table of Contents

1. [Module 1: Virtual Network Fundamentals](#module-1-virtual-network-fundamentals)
2. [Module 2: Network Security](#module-2-network-security)
3. [Module 3: Connectivity - VNet Peering](#module-3-connectivity---vnet-peering)
4. [Module 4: Hybrid Connectivity - VPN Gateway](#module-4-hybrid-connectivity---vpn-gateway)
5. [Module 5: Private Access - Private Endpoints & Service Endpoints](#module-5-private-access---private-endpoints--service-endpoints)
6. [Module 6: Load Balancing - Azure Load Balancer](#module-6-load-balancing---azure-load-balancer)
7. [Module 7: Application Delivery - Application Gateway](#module-7-application-delivery---application-gateway)
8. [Module 8: DNS & Name Resolution](#module-8-dns--name-resolution)
9. [Module 9: Network Security - Azure Firewall](#module-9-network-security---azure-firewall)
10. [Module 10: Routing - User Defined Routes & NVAs](#module-10-routing---user-defined-routes--nvas)
11. [Module 11: Secure Remote Access - Azure Bastion](#module-11-secure-remote-access---azure-bastion)
12. [Module 12: Hub-Spoke Architecture](#module-12-hub-spoke-architecture)
13. [Module 13: Global Load Balancing - Front Door & Traffic Manager](#module-13-global-load-balancing---front-door--traffic-manager)
14. [Module 14: Network Monitoring & Troubleshooting](#module-14-network-monitoring--troubleshooting)
15. [Module 15: ExpressRoute (Theoretical)](#module-15-expressroute-theoretical)
16. [Module 16: Virtual WAN (Theoretical + Optional Lab)](#module-16-virtual-wan-theoretical--optional-lab)
17. [Module 17: DDoS Protection](#module-17-ddos-protection)

---

## Module 1: Virtual Network Fundamentals

### Learning Objectives
- Understand Azure VNet address space planning and CIDR notation
- Create and configure subnets with different purposes
- Understand system routes and default routing behavior
- Learn about reserved IP addresses in Azure subnets

### Exercise 1.1: Create a Multi-Subnet Virtual Network

**Scenario:** Create a VNet with multiple subnets representing a typical enterprise setup.

**Directory:** `exercises/01-vnet-fundamentals/`

**What you'll deploy:**
- 1 Virtual Network with address space 10.0.0.0/16
- 4 Subnets: Web tier, App tier, Database tier, Management
- 1 VM in the web subnet to test connectivity

**Key Networking Concepts to Understand:**
- Address space planning and subnet sizing
- Reserved addresses (first 4 + last 1 in each subnet)
- System routes and default gateway behavior
- Subnet delegation (preparing for future exercises)

---

## Module 2: Network Security

### Learning Objectives
- Master Network Security Groups (NSGs) and rule evaluation order
- Understand Application Security Groups (ASGs) for simplified security
- Learn about service tags and their use cases
- Understand NSG flow logs and diagnostics

### Exercise 2.1: NSG Deep Dive

**Scenario:** Implement defense-in-depth with NSGs at both subnet and NIC level.

**Directory:** `exercises/02-network-security/`

**What you'll deploy:**
- VNet with 3 subnets (Web, App, DB)
- NSGs attached to subnets
- NSGs attached to NICs
- 3 VMs to test traffic flow
- Application Security Groups for role-based access

**Key Networking Concepts to Understand:**
- Rule priority (100-4096) and evaluation order
- Inbound vs Outbound rules processing
- Default rules and why they exist
- Service tags (Internet, VirtualNetwork, AzureLoadBalancer, etc.)
- Augmented security rules

### Exercise 2.2: Application Security Groups

**Scenario:** Use ASGs to group VMs by function rather than IP address.

**What you'll learn:**
- How ASGs simplify NSG rules
- Dynamic membership as VMs scale
- Combining ASGs with service tags

---

## Module 3: Connectivity - VNet Peering

### Learning Objectives
- Understand VNet peering types (regional vs global)
- Learn about peering properties and their implications
- Master the non-transitive nature of peering
- Configure gateway transit

### Exercise 3.1: Regional VNet Peering

**Scenario:** Connect two VNets in the same region and verify connectivity.

**Directory:** `exercises/03-vnet-peering/`

**What you'll deploy:**
- 2 Virtual Networks in the same region
- VMs in each VNet
- Bidirectional peering configuration

**Key Networking Concepts to Understand:**
- Peering states (Initiated, Connected)
- AllowVirtualNetworkAccess
- AllowForwardedTraffic
- AllowGatewayTransit / UseRemoteGateways
- Address space overlap restrictions

### Exercise 3.2: Global VNet Peering

**Scenario:** Connect VNets across Azure regions.

**What you'll learn:**
- Latency implications
- SKU restrictions (Basic Load Balancer doesn't work)
- Cost differences

---

## Module 4: Hybrid Connectivity - VPN Gateway

### Learning Objectives
- Understand VPN Gateway SKUs and capabilities
- Configure Site-to-Site VPN connections
- Configure Point-to-Site VPN for remote users
- Understand BGP with VPN Gateway

### Exercise 4.1: Point-to-Site VPN

**Scenario:** Set up P2S VPN to connect your local machine to Azure VNet.

**Directory:** `exercises/04-vpn-gateway/`

**What you'll deploy:**
- VNet with GatewaySubnet
- VPN Gateway (VpnGw1 SKU)
- P2S VPN configuration with certificate authentication

**Key Networking Concepts to Understand:**
- GatewaySubnet requirements (minimum /27, recommended /27)
- VPN Gateway SKUs and throughput
- IKE/IPsec tunnel establishment
- Split tunneling vs forced tunneling
- VPN client address pool

### Exercise 4.2: Site-to-Site VPN (Simulated)

**Scenario:** Create S2S VPN between two Azure VNets simulating on-premises.

**What you'll deploy:**
- 2 VNets simulating Azure and "on-premises"
- 2 VPN Gateways
- Local Network Gateways
- VPN Connection with shared key

**Key Networking Concepts:**
- Local Network Gateway purpose
- Connection types (IPsec, Vnet2Vnet)
- Active-Active vs Active-Passive
- BGP considerations

---

## Module 5: Private Access - Private Endpoints & Service Endpoints

### Learning Objectives
- Understand the difference between Service Endpoints and Private Endpoints
- Configure Private Link for PaaS services
- Work with Private DNS Zones for name resolution
- Understand network policies for private endpoints

### Exercise 5.1: Service Endpoints

**Scenario:** Secure access to Azure Storage using Service Endpoints.

**Directory:** `exercises/05-private-access/`

**What you'll deploy:**
- VNet with subnet configured for Service Endpoints
- Storage Account with firewall rules
- VM to test access

**Key Networking Concepts:**
- How Service Endpoints work (routing change)
- Service Endpoint policies
- Limitations (still uses public IP internally)

### Exercise 5.2: Private Endpoints

**Scenario:** Completely private access to Azure SQL using Private Endpoints.

**What you'll deploy:**
- VNet with subnet
- Azure SQL Server with Private Endpoint
- Private DNS Zone linked to VNet
- VM to test private name resolution

**Key Networking Concepts:**
- Private Endpoint NIC and private IP assignment
- DNS resolution flow (critical!)
- Disabling public access
- Network policies for Private Endpoints
- groupIds and subresources

---

## Module 6: Load Balancing - Azure Load Balancer

### Learning Objectives
- Understand Layer 4 load balancing concepts
- Configure internal and public load balancers
- Master health probes and their behavior
- Understand SNAT and outbound rules

### Exercise 6.1: Public Load Balancer

**Scenario:** Load balance web traffic across multiple VMs.

**Directory:** `exercises/06-load-balancer/`

**What you'll deploy:**
- VNet with subnet
- 2 VMs running web servers
- Public Load Balancer with frontend IP
- Backend pool, health probe, and load balancing rule

**Key Networking Concepts:**
- Standard vs Basic SKU differences
- Frontend IP configurations
- Backend pools (NIC-based vs IP-based)
- Health probe types (TCP, HTTP, HTTPS)
- Load balancing algorithms (5-tuple hash)
- Session persistence (None, Client IP, Client IP + Protocol)
- Idle timeout and TCP reset

### Exercise 6.2: Internal Load Balancer

**Scenario:** Load balance internal application tier traffic.

**What you'll deploy:**
- Multi-tier architecture
- Internal Load Balancer for app tier
- Cross-zone considerations

**Key Networking Concepts:**
- Internal frontend IP allocation (static vs dynamic)
- HA Ports for NVA scenarios
- Floating IP for SQL AlwaysOn

### Exercise 6.3: Outbound Rules and SNAT

**Scenario:** Configure explicit outbound connectivity.

**What you'll learn:**
- Default outbound access deprecation
- SNAT port allocation
- Outbound rules configuration
- NAT Gateway as alternative

---

## Module 7: Application Delivery - Application Gateway

### Learning Objectives
- Understand Layer 7 load balancing and SSL termination
- Configure URL-based and path-based routing
- Implement Web Application Firewall (WAF)
- Configure custom health probes

### Exercise 7.1: Basic Application Gateway

**Scenario:** Deploy Application Gateway with SSL termination.

**Directory:** `exercises/07-app-gateway/`

**What you'll deploy:**
- VNet with dedicated AppGW subnet (minimum /24 recommended)
- Application Gateway v2
- Backend pool with web servers
- HTTP settings, listener, and routing rules

**Key Networking Concepts:**
- Dedicated subnet requirement
- Frontend IP configuration (public/private)
- Listeners (HTTP vs HTTPS, multi-site)
- Backend HTTP settings (protocol, port, affinity)
- Request routing rules (Basic vs Path-based)
- Health probes and backend health

### Exercise 7.2: Path-Based Routing

**Scenario:** Route traffic to different backend pools based on URL path.

**What you'll deploy:**
- Multiple backend pools (images, videos, api)
- Path-based routing rules
- URL rewrite rules

### Exercise 7.3: Web Application Firewall

**Scenario:** Protect web applications with WAF.

**What you'll learn:**
- WAF modes (Detection vs Prevention)
- OWASP rule sets
- Custom rules
- Exclusions and tuning

---

## Module 8: DNS & Name Resolution

### Learning Objectives
- Configure Azure DNS for public domain hosting
- Implement Private DNS Zones for internal resolution
- Understand DNS resolution in VNets
- Configure Azure DNS Private Resolver

### Exercise 8.1: Azure Public DNS

**Scenario:** Host a public domain in Azure DNS.

**Directory:** `exercises/08-dns/`

**What you'll deploy:**
- Azure DNS Zone (public)
- Various record types (A, AAAA, CNAME, TXT, MX)
- Alias records pointing to Azure resources

**Key Networking Concepts:**
- DNS delegation
- Record types and TTL
- Alias vs standard records

### Exercise 8.2: Private DNS Zones

**Scenario:** Implement private name resolution across VNets.

**What you'll deploy:**
- Private DNS Zone
- VNet links (with/without auto-registration)
- VMs to test resolution

**Key Networking Concepts:**
- Auto-registration
- VNet link types
- Resolution order
- Private DNS with Private Endpoints (critical pattern)

### Exercise 8.3: Azure DNS Private Resolver

**Scenario:** Hybrid DNS resolution between Azure and on-premises.

**What you'll deploy:**
- DNS Private Resolver
- Inbound and Outbound endpoints
- DNS forwarding ruleset

**Key Networking Concepts:**
- Conditional forwarders
- Inbound resolution (on-prem → Azure)
- Outbound resolution (Azure → on-prem)

---

## Module 9: Network Security - Azure Firewall

### Learning Objectives
- Deploy and configure Azure Firewall
- Create application and network rules
- Implement DNAT for inbound traffic
- Understand Firewall Manager and policies

### Exercise 9.1: Azure Firewall Basics

**Scenario:** Centralized network security with Azure Firewall.

**Directory:** `exercises/09-azure-firewall/`

**What you'll deploy:**
- Hub VNet with AzureFirewallSubnet
- Spoke VNet with workloads
- Azure Firewall (Standard SKU)
- Route table for forced tunneling

**Key Networking Concepts:**
- AzureFirewallSubnet size requirements (minimum /26)
- SNAT behavior
- Rule types and processing order:
  1. DNAT rules
  2. Network rules
  3. Application rules
- Threat intelligence
- FQDN tags vs FQDN filtering

### Exercise 9.2: Advanced Firewall Rules

**Scenario:** Complex rule configuration.

**What you'll deploy:**
- Application rules for web filtering
- Network rules for non-HTTP traffic
- DNAT rules for inbound services
- IP Groups for management

### Exercise 9.3: Firewall Manager

**Scenario:** Centralized firewall policy management.

**What you'll learn:**
- Firewall policies and hierarchy
- Secured virtual hubs
- Third-party SECaaS integration

---

## Module 10: Routing - User Defined Routes & NVAs

### Learning Objectives
- Understand Azure routing fundamentals
- Create and apply User Defined Routes
- Implement Network Virtual Appliances
- Configure IP forwarding

### Exercise 10.1: User Defined Routes

**Scenario:** Override default routing to force traffic through NVA.

**Directory:** `exercises/10-routing/`

**What you'll deploy:**
- Hub-Spoke VNet topology
- NVA VM with IP forwarding enabled
- Route tables with custom routes

**Key Networking Concepts:**
- System routes vs User Defined Routes
- Route selection (longest prefix match)
- Next hop types:
  - Virtual network gateway
  - Virtual network
  - Internet
  - Virtual appliance
  - None
- Border Gateway Protocol (BGP) route propagation
- Route table association

### Exercise 10.2: Routing to Azure Firewall

**Scenario:** Force all internet-bound traffic through Azure Firewall.

**What you'll deploy:**
- Hub VNet with Azure Firewall
- Spoke VNets with workloads
- Route tables with 0.0.0.0/0 → Firewall

**Key Networking Concepts:**
- Asymmetric routing issues
- Return traffic paths
- Service Endpoint compatibility

---

## Module 11: Secure Remote Access - Azure Bastion

### Learning Objectives
- Deploy and configure Azure Bastion
- Understand Bastion SKUs and features
- Configure native client support/IP-based connection

### Exercise 11.1: Azure Bastion Deployment

**Scenario:** Secure RDP/SSH access without public IPs.

**Directory:** `exercises/11-bastion/`

**What you'll deploy:**
- VNet with AzureBastionSubnet (minimum /26)
- Azure Bastion (Standard SKU)
- VMs without public IPs

**Key Networking Concepts:**
- AzureBastionSubnet requirements
- Bastion communication flow
- NSG rules for Bastion subnet
- SKU differences (Basic vs Standard)
- Native client support (SSH/RDP client)
- Shareable links

---

## Module 12: Hub-Spoke Architecture

### Learning Objectives
- Design and implement hub-spoke topology
- Configure gateway transit
- Implement centralized network services
- Understand spoke-to-spoke communication patterns

### Exercise 12.1: Complete Hub-Spoke Network

**Scenario:** Production-like hub-spoke with all network services.

**Directory:** `exercises/12-hub-spoke/`

**What you'll deploy:**
- Hub VNet with:
  - Azure Firewall
  - Azure Bastion
  - VPN Gateway
  - DNS Private Resolver (optional)
- 2 Spoke VNets with workloads
- VNet peering with gateway transit
- Route tables for traffic inspection

**Key Networking Concepts:**
- Centralized vs distributed services
- Traffic inspection patterns
- Spoke-to-spoke via firewall
- Gateway transit configuration
- Cost optimization

---

## Module 13: Global Load Balancing - Front Door & Traffic Manager

### Learning Objectives
- Understand global vs regional load balancing
- Configure Azure Front Door
- Configure Azure Traffic Manager
- Compare use cases

### Exercise 13.1: Azure Traffic Manager

**Scenario:** DNS-based global load balancing.

**Directory:** `exercises/13-global-lb/`

**What you'll deploy:**
- Traffic Manager profile
- Endpoints in multiple regions
- Different routing methods

**Key Networking Concepts:**
- DNS-based routing
- Routing methods:
  - Priority
  - Weighted
  - Performance
  - Geographic
  - MultiValue
  - Subnet
- Endpoint monitoring
- Fast failover

### Exercise 13.2: Azure Front Door

**Scenario:** Global HTTP load balancing with WAF.

**What you'll deploy:**
- Front Door profile
- Origin groups and origins
- WAF policy
- Custom domains

**Key Networking Concepts:**
- Global anycast architecture
- Origin selection
- Caching
- WAF integration
- Private Link origins

---

## Module 14: Network Monitoring & Troubleshooting

### Learning Objectives
- Use Network Watcher tools effectively
- Configure NSG Flow Logs
- Implement Connection Monitor
- Troubleshoot common networking issues

### Exercise 14.1: Network Watcher Deep Dive

**Scenario:** Utilize all Network Watcher capabilities.

**Directory:** `exercises/14-monitoring/`

**What you'll deploy:**
- VNet with various resources
- Network Watcher (auto-created per region)
- Storage account for flow logs
- Log Analytics workspace

**Tools to Master:**
- IP flow verify
- Next hop
- Connection troubleshoot
- Packet capture
- NSG diagnostics
- VPN troubleshoot

### Exercise 14.2: NSG Flow Logs

**Scenario:** Deep visibility into network traffic.

**What you'll configure:**
- NSG Flow Logs v2
- Traffic Analytics
- Flow log queries

**Key Networking Concepts:**
- Flow log format
- Traffic Analytics insights
- Retention and storage

### Exercise 14.3: Connection Monitor

**Scenario:** Continuous connectivity monitoring.

**What you'll configure:**
- Test groups
- Multi-source/destination tests
- Alerting

---

## Module 15: ExpressRoute (Theoretical)

> ⚠️ **Note:** ExpressRoute requires physical connectivity and cannot be fully deployed in a learning environment. This module focuses on conceptual understanding.

### Learning Objectives
- Understand ExpressRoute architecture
- Learn about peering types
- Understand ExpressRoute Global Reach
- Learn about ExpressRoute Direct

### Theoretical Content

**ExpressRoute Architecture:**
```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐     ┌───────────┐
│ On-Premises │────▶│ Partner Edge │────▶│ Microsoft Edge  │────▶│ Azure VNet│
│   Network   │     │   (Meet-me)  │     │   (MSEE)        │     │           │
└─────────────┘     └──────────────┘     └─────────────────┘     └───────────┘
```

**Key Concepts:**
1. **Connectivity Models:**
   - CloudExchange co-location
   - Point-to-point Ethernet
   - Any-to-any (IPVPN)
   - ExpressRoute Direct

2. **Peering Types:**
   - Azure Private Peering (VNets)
   - Microsoft Peering (Microsoft 365, Dynamics 365, Azure PaaS)

3. **SKUs:**
   - Local (same metro only)
   - Standard (same geopolitical region)
   - Premium (global connectivity)

4. **Redundancy:**
   - Active-active connections
   - Two circuits for SLA
   - ExpressRoute Global Reach

5. **Security Considerations:**
   - Private connectivity (not encrypted by default)
   - MACsec with ExpressRoute Direct
   - IPsec over ExpressRoute

### Thought Exercises
1. Design ExpressRoute for a multi-region deployment
2. Compare ExpressRoute vs VPN for different scenarios
3. Calculate bandwidth requirements

---

## Module 16: Virtual WAN (Theoretical + Optional Lab)

> ⚠️ **Note:** Virtual WAN can be expensive for learning. Review theoretical content first, deploy only if budget allows.

### Learning Objectives
- Understand Virtual WAN architecture
- Compare hub-spoke vs Virtual WAN
- Learn about secured virtual hubs

### Theoretical Content

**Virtual WAN Architecture:**
```
                    ┌─────────────────────────────────────┐
                    │         Azure Virtual WAN           │
                    │  ┌─────────┐       ┌─────────┐     │
Branch ─────────────┼─▶│  Hub 1  │◀─────▶│  Hub 2  │◀────┼───── VNet
                    │  │ Region A│       │ Region B│     │
On-Prem ────────────┼─▶│         │       │         │◀────┼───── VNet
(ER/VPN)            │  └─────────┘       └─────────┘     │
                    └─────────────────────────────────────┘
```

**Key Concepts:**
1. **Hub Types:**
   - Basic (VPN only)
   - Standard (full routing)

2. **Connection Types:**
   - VNet connections
   - Site-to-Site VPN
   - Point-to-Site VPN
   - ExpressRoute

3. **Routing:**
   - Virtual hub routing
   - Route tables
   - Routing intent

4. **Secured Virtual Hub:**
   - Azure Firewall integration
   - Third-party NVA

### Optional Lab (⚠️ Cost Warning)

**Exercise 16.1: Basic Virtual WAN**

Deploy if budget allows:
- Virtual WAN
- Hub in one region
- Connected VNets
- P2S VPN gateway

---

## Module 17: DDoS Protection

### Learning Objectives
- Understand DDoS attack types
- Configure DDoS Protection Plan
- Understand attack mitigation

### Exercise 17.1: DDoS Protection Plan

> ⚠️ **Note:** DDoS Protection Plan has a fixed monthly cost (~$2,944/month). Consider creating for short duration only.

**Directory:** `exercises/17-ddos/`

**Alternative Learning:**
- Use Azure DDoS Protection Basic (free, automatic)
- Review DDoS Protection simulations in documentation
- Study attack reports and mitigation policies

**Key Networking Concepts:**
- L3/L4 attack mitigation
- Adaptive tuning
- Attack analytics
- DDoS Rapid Response (DRR)
- Cost protection

---

## Recommended Learning Path

### Week 1-2: Foundations
1. Module 1: Virtual Network Fundamentals
2. Module 2: Network Security
3. Module 3: VNet Peering

### Week 3-4: Connectivity & Access
4. Module 4: VPN Gateway
5. Module 5: Private Endpoints & Service Endpoints
6. Module 8: DNS & Name Resolution

### Week 5-6: Load Balancing
7. Module 6: Azure Load Balancer
8. Module 7: Application Gateway
9. Module 13: Global Load Balancing

### Week 7-8: Security & Architecture
10. Module 9: Azure Firewall
11. Module 10: Routing & NVAs
12. Module 11: Azure Bastion
13. Module 12: Hub-Spoke Architecture

### Week 9-10: Operations & Advanced
14. Module 14: Network Monitoring
15. Module 15: ExpressRoute (Theory)
16. Module 16: Virtual WAN (Theory)
17. Module 17: DDoS Protection

---

## Cost Management Tips

1. **Use Azure pricing calculator** before deploying
2. **Delete resources immediately** after each exercise
3. **Use Dev/Test subscriptions** if available
4. **Avoid 24/7 resources:** VPN Gateway, App Gateway, Firewall
5. **Use Basic SKUs** for learning when possible
6. **Set budget alerts** in Azure Cost Management

---

## Exercise Conventions

Each exercise folder contains:
```
exercises/XX-topic-name/
├── README.md           # Detailed exercise instructions
├── main.bicep          # Main deployment template
├── modules/            # Bicep modules (if applicable)
├── parameters/         # Parameter files
│   └── dev.bicepparam  # Development parameters
├── deploy.sh           # Deployment script
└── cleanup.sh          # Resource cleanup script
```

---

## Getting Started

Ready to begin? Start with Module 1 and request:

> "Create the exercise files for Module 1: Virtual Network Fundamentals"

I'll generate:
- Detailed Bicep templates with extensive networking comments
- Azure CLI deployment scripts
- Step-by-step instructions
- Verification tests

---

## Next Steps

Please review this learning plan and let me know:

1. **Any topics to add or remove?**
2. **Adjust the order of modules?**
3. **Ready to start creating exercise files for a specific module?**
4. **Want more theoretical depth on any topic before exercises?**
