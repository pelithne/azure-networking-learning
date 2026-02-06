# Module 4: VPN Gateway

## Overview

Azure VPN Gateway provides hybrid connectivity using encrypted IPsec/IKE tunnels. This module covers Point-to-Site (P2S) VPN for remote users and Site-to-Site (S2S) VPN for connecting networks.

> ⚠️ **Deployment Warning:** VPN Gateway takes **30-45 minutes** to deploy. Plan accordingly.

## Learning Objectives

By completing this exercise, you will:

1. **Understand VPN Gateway SKUs** and their capabilities
2. **Deploy and configure P2S VPN** with certificate authentication
3. **Understand S2S VPN** concepts (simulated with VNet-to-VNet)
4. **Learn about active-active** vs active-standby configurations
5. **Understand BGP** with VPN Gateway

## Prerequisites

- Completed Modules 1-3
- OpenSSL installed (for certificate generation)
- VPN client software (built into Windows, or strongSwan for Linux)

## Architecture

### Exercise 4.1: Point-to-Site VPN

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Azure VNet                                      │
│                           10.0.0.0/16                                        │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │              GatewaySubnet: 10.0.255.0/27                            │   │
│   │                                                                      │   │
│   │                    ┌─────────────────┐                               │   │
│   │                    │   VPN Gateway   │◄──── P2S VPN Tunnel          │   │
│   │                    │   (VpnGw1)      │      172.16.0.0/24           │   │
│   │                    └─────────────────┘                               │   │
│   │                            │                         ┌─────────────┐   │
│   └────────────────────────────┼─────────────────────────┤  Your       │   │
│                                │                         │  Laptop     │   │
│   ┌────────────────────────────┼────────────────────┐    │ 172.16.0.2  │   │
│   │     Workload Subnet: 10.0.1.0/24                │    └─────────────┘   │
│   │                            │                     │                      │
│   │   ┌──────────────┐         │                     │                      │
│   │   │   vm-server  │◄────────┘                     │                      │
│   │   │   10.0.1.4   │                               │                      │
│   │   └──────────────┘                               │                      │
│   └──────────────────────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Exercise 4.2: Site-to-Site VPN (Simulated)

```
┌──────────────────────────────────┐       ┌──────────────────────────────────┐
│        "Azure" VNet              │       │      "On-Premises" VNet          │
│        10.0.0.0/16               │       │        192.168.0.0/16            │
│                                  │       │                                  │
│  ┌────────────────────────────┐  │       │  ┌────────────────────────────┐  │
│  │     GatewaySubnet          │  │       │  │     GatewaySubnet          │  │
│  │     10.0.255.0/27          │  │       │  │     192.168.255.0/27       │  │
│  │                            │  │       │  │                            │  │
│  │   ┌──────────────────┐     │  │       │  │   ┌──────────────────┐     │  │
│  │   │   VPN Gateway    │◄────┼──┼───────┼──┼──►│   VPN Gateway    │     │  │
│  │   │   (azure-gw)     │     │  │ IPsec │  │   │   (onprem-gw)    │     │  │
│  │   └──────────────────┘     │  │ Tunnel│  │   └──────────────────┘     │  │
│  │                            │  │       │  │                            │  │
│  └────────────────────────────┘  │       │  └────────────────────────────┘  │
│                                  │       │                                  │
│  ┌────────────────────────────┐  │       │  ┌────────────────────────────┐  │
│  │   Workload Subnet          │  │       │  │   Workload Subnet          │  │
│  │   10.0.1.0/24              │  │       │  │   192.168.1.0/24           │  │
│  │                            │  │       │  │                            │  │
│  │   ┌────────────────┐       │  │       │  │   ┌────────────────┐       │  │
│  │   │   vm-azure     │       │  │       │  │   │   vm-onprem    │       │  │
│  │   │   10.0.1.4     │       │  │       │  │   │   192.168.1.4  │       │  │
│  │   └────────────────┘       │  │       │  │   └────────────────┘       │  │
│  └────────────────────────────┘  │       │  └────────────────────────────┘  │
└──────────────────────────────────┘       └──────────────────────────────────┘
```

## Key Networking Concepts

### 1. VPN Gateway SKUs

| SKU | Max S2S Tunnels | Max P2S Connections | Throughput | Active-Active | BGP |
|-----|-----------------|---------------------|------------|---------------|-----|
| Basic | 10 | 128 | 100 Mbps | No | No |
| VpnGw1 | 30 | 250 | 650 Mbps | Yes | Yes |
| VpnGw2 | 30 | 500 | 1 Gbps | Yes | Yes |
| VpnGw3 | 30 | 1000 | 1.25 Gbps | Yes | Yes |
| VpnGw4 | 100 | 5000 | 5 Gbps | Yes | Yes |
| VpnGw5 | 100 | 10000 | 10 Gbps | Yes | Yes |

**SKU Selection Criteria:**
- **Basic**: Dev/test only, no SLA, being deprecated
- **VpnGw1**: Small production workloads
- **VpnGw2+**: Higher throughput, more tunnels
- **Add "AZ" suffix (VpnGw1AZ)**: Zone-redundant for HA

### 2. GatewaySubnet Requirements

| Requirement | Value | Notes |
|-------------|-------|-------|
| Name | Must be "GatewaySubnet" | Exact name required |
| Minimum Size | /29 (8 IPs) | For single gateway |
| Recommended | /27 (32 IPs) | For future growth, ExpressRoute coexistence |
| NSG | Not recommended | Can break gateway functionality |
| UDR | Careful consideration | May affect gateway traffic |

### 3. Point-to-Site Authentication Methods

| Method | Complexity | Use Case |
|--------|------------|----------|
| Azure Certificate | Medium | Enterprise with PKI |
| RADIUS | High | Integrate with existing auth |
| Azure AD | Low | Microsoft 365 users |
| OpenVPN | Medium | Cross-platform support |

### 4. VPN Types

| Type | Description | Protocol |
|------|-------------|----------|
| Route-based | Uses routing table | IKEv2, OpenVPN, SSTP |
| Policy-based | Uses traffic selectors | IKEv1 only, Basic SKU |

**Always use Route-based** for:
- P2S VPN support
- VNet-to-VNet connections
- Multiple S2S tunnels
- Transit routing

### 5. Active-Active Configuration

```
Normal (Active-Standby):           Active-Active:
┌───────────────────────┐         ┌───────────────────────┐
│    VPN Gateway        │         │    VPN Gateway        │
│  ┌─────┐   ┌─────┐   │         │  ┌─────┐   ┌─────┐   │
│  │ VM1 │   │ VM2 │   │         │  │ VM1 │   │ VM2 │   │
│  │Active│   │Stby │   │         │  │Active│   │Active│   │
│  └──┬──┘   └─────┘   │         │  └──┬──┘   └──┬──┘   │
│     │                 │         │     │         │       │
│  PIP1               │         │  PIP1      PIP2       │
└─────┼─────────────────┘         └─────┼─────────┼───────┘
      │                                 │         │
      ▼                                 ▼         ▼
  On-Prem                           On-Prem (2 tunnels)
```

## Exercise 4.1: Point-to-Site VPN

### Step 1: Generate Certificates

```bash
# Create directory for certificates
mkdir -p ~/vpn-certs && cd ~/vpn-certs

# Generate Root CA private key
openssl genrsa -out ca-key.pem 4096

# Generate Root CA certificate
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem \
  -subj "/CN=AzureVPNRootCA"

# Generate client private key
openssl genrsa -out client-key.pem 4096

# Generate client certificate signing request
openssl req -new -key client-key.pem -out client-csr.pem \
  -subj "/CN=AzureVPNClient"

# Sign client certificate with Root CA
openssl x509 -req -days 365 -in client-csr.pem \
  -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
  -out client-cert.pem

# Extract Root CA public key for Azure (Base64 encoded)
ROOT_CERT_DATA=$(openssl x509 -in ca-cert.pem -outform der | base64 -w0)
echo "Root Certificate (copy this for Azure):"
echo "$ROOT_CERT_DATA"

# Create PKCS12 for client (combine key + cert)
openssl pkcs12 -export -out client.p12 \
  -inkey client-key.pem -in client-cert.pem \
  -certfile ca-cert.pem -passout pass:azure123
```

### Step 2: Deploy VPN Gateway

```bash
cd exercises/04-vpn-gateway

# Edit parameters to include your root certificate
# (or deploy will prompt you)
./deploy.sh
```

> ⏱️ **Note:** VPN Gateway deployment takes 30-45 minutes. Go get coffee! ☕

### Step 3: Download VPN Client

```bash
# After deployment, download VPN client configuration
az network vnet-gateway vpn-client generate \
  --resource-group rg-learn-vpn-gateway \
  --name vpn-gw-azure \
  --processor-architecture Amd64

# This returns a URL - download the zip file
# Extract and find the configuration for your OS
```

### Step 4: Connect to VPN

**Windows:**
1. Import `client.p12` to Personal certificates
2. Install VPN client from downloaded package
3. Connect via Windows VPN settings

**Linux (strongSwan):**
```bash
# Install strongSwan
sudo apt install strongswan strongswan-pki libcharon-extra-plugins

# Copy configuration (varies by distribution)
# Use OpenVPN configuration from downloaded package
```

### Step 5: Test Connectivity

```bash
# Once VPN connected, test access to Azure VM
ping 10.0.1.4

# SSH to the private VM
ssh azureuser@10.0.1.4
```

## Exercise 4.2: Site-to-Site VPN (Simulated)

This exercise uses two Azure VNets to simulate an on-premises to Azure connection.

### Step 1: Deploy Both Gateways

The main Bicep template deploys both VNets and gateways:

```bash
./deploy-s2s.sh

# This creates:
# - "Azure" VNet with VPN Gateway
# - "On-Prem" VNet with VPN Gateway (simulated)
# - Local Network Gateways on each side
# - VPN Connection between them
```

### Step 2: Verify Connection Status

```bash
# Check connection status
az network vpn-connection show \
  --resource-group rg-learn-vpn-gateway \
  --name azure-to-onprem \
  --query "{Status:connectionStatus,Egress:egressBytesTransferred,Ingress:ingressBytesTransferred}"

# Expected: Status = Connected
```

### Step 3: Test Cross-Network Connectivity

```bash
# SSH to Azure VM (has public IP)
ssh azureuser@<azure-vm-public-ip>

# Ping the "on-premises" VM through VPN tunnel
ping 192.168.1.4

# SSH to on-prem VM through tunnel
ssh azureuser@192.168.1.4

# Check routing - should see routes through gateway
ip route show
```

## Verification Checklist

### Exercise 4.1 (P2S)
- [ ] Root certificate uploaded to gateway
- [ ] VPN client downloaded and configured
- [ ] VPN connection established (get IP from client pool)
- [ ] Can ping/SSH to Azure VM through tunnel

### Exercise 4.2 (S2S)
- [ ] Both VPN gateways deployed
- [ ] Local Network Gateways configured
- [ ] Connection status shows "Connected"
- [ ] Can ping between VNets through tunnel

## Deep Dive: The Bicep Template

Study `main.bicep` to understand:

1. **GatewaySubnet** - Why it's required and how it's sized
2. **VPN Gateway resource** - SKU, type, and IP configuration
3. **Public IP for gateway** - Standard SKU requirements
4. **vpnClientConfiguration** - Address pool and authentication
5. **Local Network Gateway** - Representing the remote network
6. **Connection resource** - Linking gateways with shared key

## Cost Considerations

| Resource | Approximate Cost (USD) |
|----------|------------------------|
| VpnGw1 | ~$140/month |
| VpnGw1AZ | ~$200/month |
| Data transfer | ~$0.035-0.15/GB |

**💡 Tip:** Delete the gateway immediately after exercises to minimize cost.

## Cleanup

```bash
./cleanup.sh
```

**Important:** Gateway deletion also takes 15-20 minutes.

## Common Issues

| Issue | Solution |
|-------|----------|
| Gateway stuck in "Updating" | Wait 45 minutes, it's normal |
| P2S connect fails | Verify client certificate chain |
| S2S not connecting | Check shared keys match exactly |
| Routing not working | Verify Local Network Gateway has correct prefixes |

## What's Next?

In **Module 5: Private Endpoints**, you'll:
- Access PaaS services privately
- Configure Private DNS Zones
- Understand Service Endpoints vs Private Endpoints

## Additional Resources

- [VPN Gateway documentation](https://learn.microsoft.com/azure/vpn-gateway/)
- [P2S configuration](https://learn.microsoft.com/azure/vpn-gateway/point-to-site-about)
- [S2S configuration](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-site-to-site-resource-manager-portal)
