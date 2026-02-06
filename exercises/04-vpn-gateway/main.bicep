// ============================================================================
// Module 4: VPN Gateway - Point-to-Site
// ============================================================================
// This template deploys a VPN Gateway configured for Point-to-Site (P2S)
// connections using certificate authentication.
//
// DEPLOYMENT TIME: 30-45 minutes (VPN Gateway is slow to provision)
//
// NETWORKING CONCEPTS COVERED:
// - VPN Gateway SKUs and capabilities
// - GatewaySubnet requirements
// - P2S VPN client configuration
// - Certificate-based authentication
// - VPN client address pool
// ============================================================================

// ----------------------------------------------------------------------------
// PARAMETERS
// ----------------------------------------------------------------------------

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('VM administrator username')
param adminUsername string = 'azureuser'

@secure()
@description('VM administrator password')
param adminPassword string

@description('Root certificate public data (Base64 encoded, no headers)')
@metadata({
  howToGenerate: '''
  Generate with OpenSSL:
  1. openssl genrsa -out ca-key.pem 4096
  2. openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem -subj "/CN=AzureVPNRootCA"
  3. openssl x509 -in ca-cert.pem -outform der | base64 -w0
  
  The output of step 3 is what you provide here.
  '''
})
param vpnClientRootCertData string = ''

// ----------------------------------------------------------------------------
// VARIABLES
// ----------------------------------------------------------------------------

var vnetName = 'vnet-vpn-demo'
var vnetAddressSpace = '10.0.0.0/16'

// ============================================================================
// GATEWAYSUBNET CONFIGURATION
// ============================================================================
// The GatewaySubnet is a SPECIAL subnet required for VPN and ExpressRoute.
//
// CRITICAL REQUIREMENTS:
// 1. Name MUST be exactly "GatewaySubnet" - Azure looks for this name
// 2. Minimum size: /29 (8 IPs, but only 5 usable)
// 3. Recommended size: /27 (32 IPs) for:
//    - Active-active deployments (need 2 IPs)
//    - ExpressRoute coexistence
//    - Future growth
//
// WHAT LIVES HERE:
// - VPN Gateway instances (2 VMs in active-standby or active-active)
// - ExpressRoute Gateway instances (if deployed)
//
// RESTRICTIONS:
// - Cannot deploy regular VMs or other resources
// - NSG association is NOT RECOMMENDED (can break gateway)
// - UDRs require careful planning (can affect gateway management traffic)
// ============================================================================
var gatewaySubnetPrefix = '10.0.255.0/27'  // /27 recommended size
var workloadSubnetPrefix = '10.0.1.0/24'

// VPN client address pool - addresses assigned to connecting clients
// This range MUST NOT overlap with any VNet address space
var vpnClientAddressPool = '172.16.0.0/24'

// ============================================================================
// NETWORK SECURITY GROUP
// ============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-workload'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'AllowICMP'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ============================================================================
// VIRTUAL NETWORK
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressSpace]
    }
    subnets: [
      // ======================================================================
      // GATEWAY SUBNET
      // ======================================================================
      // This subnet hosts the VPN Gateway instances.
      //
      // IMPORTANT DESIGN DECISIONS:
      //
      // SIZE CONSIDERATIONS:
      // - /29 minimum (5 usable IPs) - works for basic active-standby
      // - /28 (11 usable) - allows some growth
      // - /27 (27 usable) - recommended for production:
      //   * Supports active-active (needs 2 gateway IPs)
      //   * Allows ExpressRoute + VPN coexistence
      //   * Provides expansion room
      //
      // NO NSG ASSOCIATION:
      // We intentionally do NOT attach an NSG to GatewaySubnet.
      // Azure manages security for the gateway infrastructure.
      // Attaching NSG can break:
      // - Gateway management traffic
      // - IKE negotiation traffic
      // - BGP peering
      // ======================================================================
      {
        name: 'GatewaySubnet'  // Name MUST be exactly this
        properties: {
          addressPrefix: gatewaySubnetPrefix
          // NOTE: No NSG attached - this is intentional!
        }
      }
      {
        name: 'snet-workload'
        properties: {
          addressPrefix: workloadSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP FOR VPN GATEWAY
// ============================================================================
// VPN Gateway requires a public IP for:
// - Clients to connect to (P2S)
// - Sites to establish tunnels with (S2S)
// - IKE negotiation
// ============================================================================

resource gatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vpn-gateway'
  location: location
  
  // ==========================================================================
  // SKU REQUIREMENTS
  // ==========================================================================
  // For VPN Gateway Gen2 (VpnGw1 and above):
  // - MUST use Standard SKU public IP
  // - MUST use Static allocation
  //
  // For zone-redundant gateway (VpnGw1AZ, etc.):
  // - MUST use Standard SKU
  // - Public IP is automatically zone-redundant
  // ==========================================================================
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// VPN GATEWAY
// ============================================================================
// The VPN Gateway provides IPsec/IKE VPN connectivity.
//
// DEPLOYMENT TIME: 30-45 minutes
// This is because Azure creates 2 VM instances behind the scenes
// and configures all the networking infrastructure.
// ============================================================================

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: 'vpn-gw-azure'
  location: location
  
  properties: {
    // ========================================================================
    // GATEWAY TYPE
    // ========================================================================
    // - Vpn: For VPN connections (IPsec/IKE)
    // - ExpressRoute: For ExpressRoute circuits
    //
    // You cannot change this after deployment - must delete and recreate.
    // ========================================================================
    gatewayType: 'Vpn'
    
    // ========================================================================
    // VPN TYPE
    // ========================================================================
    // - RouteBased: Uses virtual routing and forwarding (VRF)
    //   * Supports IKEv2 and OpenVPN
    //   * Required for P2S
    //   * Required for multiple S2S tunnels
    //   * Supports VNet-to-VNet
    //
    // - PolicyBased: Uses traffic selectors / security policies
    //   * Only IKEv1
    //   * Single S2S tunnel only
    //   * No P2S support
    //   * Legacy, avoid unless required by on-prem device
    //
    // ALWAYS USE RouteBased unless you have a specific reason.
    // ========================================================================
    vpnType: 'RouteBased'
    
    // ========================================================================
    // VPN GATEWAY GENERATION
    // ========================================================================
    // Generation2 gateways:
    // - Support higher throughput
    // - Required for larger SKUs (VpnGw4, VpnGw5)
    // - Use Standard SKU public IP
    // ========================================================================
    vpnGatewayGeneration: 'Generation2'
    
    // ========================================================================
    // SKU SELECTION
    // ========================================================================
    // VpnGw1 provides:
    // - Up to 650 Mbps throughput
    // - 30 S2S tunnels max
    // - 250 P2S connections max
    // - BGP support
    // - Active-active support
    // - Zone redundancy available (VpnGw1AZ)
    //
    // For this learning exercise, VpnGw1 is sufficient and cost-effective.
    // Production might use VpnGw2 or higher for more throughput.
    // ========================================================================
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
    
    // ========================================================================
    // ACTIVE-ACTIVE MODE
    // ========================================================================
    // When true:
    // - Azure provisions 2 gateway instances with 2 public IPs
    // - Both instances actively handle traffic
    // - Higher availability during planned maintenance
    // - Requires 2 public IPs and 2 tunnels to on-prem
    //
    // When false (default):
    // - 2 instances but only 1 active (standby for HA)
    // - Single public IP
    // - Simpler on-prem configuration
    //
    // For P2S only scenarios, active-standby is usually sufficient.
    // ========================================================================
    activeActive: false
    
    // ========================================================================
    // ENABLE BGP
    // ========================================================================
    // BGP (Border Gateway Protocol) allows:
    // - Dynamic route exchange with on-premises
    // - Automatic route updates when networks change
    // - Transit routing scenarios
    //
    // For simple P2S, BGP isn't necessary.
    // Enable for complex hybrid or multi-site scenarios.
    // ========================================================================
    enableBgp: false
    // If BGP enabled, configure ASN:
    // bgpSettings: {
    //   asn: 65515  // Azure default, can change
    // }
    
    // ========================================================================
    // IP CONFIGURATION
    // ========================================================================
    // This connects the gateway to the GatewaySubnet and assigns public IP.
    // ========================================================================
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            // Reference the GatewaySubnet
            id: '${vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: gatewayPublicIp.id
          }
        }
      }
    ]
    
    // ========================================================================
    // VPN CLIENT CONFIGURATION (P2S)
    // ========================================================================
    // This section configures Point-to-Site VPN for remote user access.
    // ========================================================================
    vpnClientConfiguration: {
      // ======================================================================
      // VPN CLIENT ADDRESS POOL
      // ======================================================================
      // IP addresses assigned to VPN clients when they connect.
      //
      // CRITICAL REQUIREMENTS:
      // - MUST NOT overlap with any VNet address space
      // - MUST NOT overlap with on-premises networks
      // - Size depends on expected concurrent connections
      //
      // /24 provides 251 usable addresses (minus Azure reserved)
      // ======================================================================
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      
      // ======================================================================
      // VPN PROTOCOLS
      // ======================================================================
      // - OpenVPN: Cross-platform, port 443 (firewall-friendly)
      // - IkeV2: Native Windows/macOS support, better performance
      // - SSTP: Windows only, TCP 443 (legacy)
      //
      // Enabling multiple protocols gives clients flexibility.
      // ======================================================================
      vpnClientProtocols: [
        'OpenVPN'
        'IkeV2'
      ]
      
      // ======================================================================
      // AUTHENTICATION METHODS
      // ======================================================================
      // For certificate auth, we specify root certificates.
      // Clients present certificates signed by these root CAs.
      //
      // Other options:
      // - Azure AD authentication (recommended for organizations)
      // - RADIUS (integrate with existing auth systems)
      // ======================================================================
      vpnAuthenticationTypes: [
        'Certificate'
      ]
      
      // Root certificates for client validation
      // Clients must have certificates signed by one of these CAs
      vpnClientRootCertificates: vpnClientRootCertData != '' ? [
        {
          name: 'RootCert'
          properties: {
            // Base64-encoded X.509 certificate (no headers/footers)
            publicCertData: vpnClientRootCertData
          }
        }
      ] : []
      
      // Revoked certificates - clients with these are denied
      // vpnClientRevokedCertificates: [
      //   {
      //     name: 'RevokedCert1'
      //     properties: {
      //       thumbprint: 'CERTIFICATE_THUMBPRINT_HERE'
      //     }
      //   }
      // ]
    }
  }
}

// ============================================================================
// TEST VM
// ============================================================================
// A VM in the workload subnet to test VPN connectivity.
// This VM has NO public IP - only accessible via VPN.
// ============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-server'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/snet-workload'
          }
          // NO PUBLIC IP - only accessible via VPN
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-server'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'vm-server'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('VPN Gateway public IP - clients connect to this')
output gatewayPublicIp string = gatewayPublicIp.properties.ipAddress

@description('VPN client address pool')
output vpnClientAddressPool string = vpnClientAddressPool

@description('VM private IP - test connectivity to this after VPN connects')
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress

@description('Gateway resource ID for VPN client download')
output gatewayId string = vpnGateway.id

@description('Download VPN client command')
output downloadVpnClientCommand string = 'az network vnet-gateway vpn-client generate --resource-group ${resourceGroup().name} --name ${vpnGateway.name} --processor-architecture Amd64'

// ============================================================================
// P2S VPN TRAFFIC FLOW
// ============================================================================
//
//  Your Laptop                    VPN Gateway                    Azure VM
//  (VPN Client)                   (Internet Edge)                (Private)
//  172.16.0.2                     pip: x.x.x.x                   10.0.1.4
//       │                              │                              │
//       │  1. IKE negotiation          │                              │
//       │─────────────────────────────►│                              │
//       │  2. Certificate auth         │                              │
//       │◄─────────────────────────────│                              │
//       │  3. IPsec tunnel established │                              │
//       │══════════════════════════════│                              │
//       │                              │                              │
//       │  4. Traffic to 10.0.1.4      │  5. Routed to VM            │
//       │═══════════════encrypted══════│─────────────────────────────►│
//       │                              │                              │
//       │  7. Response encrypted       │  6. Response from VM        │
//       │◄══════════════════════════════│◄─────────────────────────────│
//       │                              │                              │
//
// KEY POINTS:
// - All traffic between client and gateway is encrypted (IPsec)
// - Client gets IP from vpnClientAddressPool (172.16.0.x)
// - Client routes to Azure VNet (10.0.0.0/16) go through tunnel
// - Split tunneling: Only Azure traffic uses VPN (default)
// ============================================================================
