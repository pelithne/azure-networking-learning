// ============================================================================
// Module 1: Virtual Network Fundamentals
// ============================================================================
// This template deploys a Virtual Network with multiple subnets to demonstrate
// foundational Azure networking concepts.
//
// NETWORKING CONCEPTS COVERED:
// - Address space planning and CIDR notation
// - Subnet design for different tiers
// - Reserved IP addresses in Azure subnets
// - System routes (default routing behavior)
// - Network Interface configuration
// ============================================================================

// ----------------------------------------------------------------------------
// PARAMETERS
// ----------------------------------------------------------------------------

@description('Azure region for all resources. Networking resources are regional.')
param location string = resourceGroup().location

@description('Environment name used for resource naming')
param environmentName string = 'learn'

@description('Administrator username for the VM')
param adminUsername string = 'azureuser'

@description('Administrator password for the VM')
@secure()
param adminPassword string

@description('The address space for the entire Virtual Network in CIDR notation')
@metadata({
  explanation: '''
  CIDR NOTATION EXPLAINED:
  - 10.0.0.0/16 means the first 16 bits are the network portion
  - This gives us 65,536 IP addresses (2^16)
  - Range: 10.0.0.0 - 10.0.255.255
  
  WHY /16?
  - Large enough for enterprise growth
  - Easy to subnet with /24 blocks (256 subnets possible)
  - Follows Azure best practices for hub-spoke designs
  
  PLANNING CONSIDERATIONS:
  - Don't overlap with on-premises networks
  - Don't overlap with other VNets you'll peer with
  - Plan for 3-5 years of growth
  '''
})
param vnetAddressSpace string = '10.0.0.0/16'

// ----------------------------------------------------------------------------
// VARIABLES
// ----------------------------------------------------------------------------

// Resource naming following Azure naming conventions
var vnetName = 'vnet-${environmentName}'
var vmName = 'vm-web'
var nicName = 'nic-${vmName}'
var publicIpName = 'pip-${vmName}'
var nsgName = 'nsg-${vmName}'

// ============================================================================
// SUBNET DEFINITIONS
// ============================================================================
// 
// SUBNET DESIGN RATIONALE:
// We're creating a typical 3-tier architecture with a management subnet:
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  Address Space: 10.0.0.0/16 (65,536 addresses)                          │
// ├─────────────────────────────────────────────────────────────────────────┤
// │  10.0.0.0/24   - Reserved for future GatewaySubnet                      │
// │  10.0.1.0/24   - Web tier (public-facing resources)                     │
// │  10.0.2.0/24   - App tier (application servers)                         │
// │  10.0.3.0/24   - DB tier (databases)                                    │
// │  10.0.4-254    - Available for growth                                   │
// │  10.0.255.0/24 - Management (jump boxes, bastion)                       │
// └─────────────────────────────────────────────────────────────────────────┘
//
// WHY THIS LAYOUT?
// 1. Low numbers (1-3) for application tiers - easy to remember
// 2. Leave 10.0.0.0/24 free for GatewaySubnet if needed later
// 3. Management at 255 - clearly separated, easy to identify
// 4. Plenty of room for new subnets (4-254)
// ============================================================================

var subnets = [
  {
    name: 'snet-web'
    addressPrefix: '10.0.1.0/24'
    description: 'Web tier - public-facing resources like web servers, API gateways'
    // RESERVED ADDRESSES IN THIS SUBNET:
    // 10.0.1.0   - Network address (cannot be used)
    // 10.0.1.1   - Azure default gateway (internal router)
    // 10.0.1.2   - Azure DNS (maps to 168.63.129.16)
    // 10.0.1.3   - Azure DNS (secondary)
    // 10.0.1.255 - Broadcast address
    // USABLE: 10.0.1.4 - 10.0.1.254 (251 addresses)
  }
  {
    name: 'snet-app'
    addressPrefix: '10.0.2.0/24'
    description: 'Application tier - middle-tier services, business logic'
  }
  {
    name: 'snet-db'
    addressPrefix: '10.0.3.0/24'
    description: 'Database tier - SQL servers, Cosmos DB private endpoints'
  }
  {
    name: 'snet-management'
    addressPrefix: '10.0.255.0/24'
    description: 'Management - jump boxes, monitoring agents, admin access'
  }
]

// ============================================================================
// VIRTUAL NETWORK
// ============================================================================

@description('The Virtual Network containing all subnets')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  
  // TAGS: Always tag networking resources for:
  // - Cost allocation
  // - Environment identification  
  // - Automation (auto-shutdown, etc.)
  tags: {
    environment: environmentName
    purpose: 'learning-azure-networking'
    module: '01-vnet-fundamentals'
  }
  
  properties: {
    // ========================================================================
    // ADDRESS SPACE
    // ========================================================================
    // The addressSpace defines the overall IP range for this VNet.
    // 
    // CRITICAL NETWORKING CONCEPTS:
    // 
    // 1. CANNOT OVERLAP with:
    //    - Other VNets you want to peer with
    //    - On-premises networks (for hybrid connectivity)
    //    - Azure reserved ranges (224.0.0.0/4, etc.)
    //
    // 2. CAN ADD multiple address spaces:
    //    addressPrefixes: ['10.0.0.0/16', '10.1.0.0/16']
    //    But this complicates routing - prefer contiguous space
    //
    // 3. CAN EXPAND later:
    //    You can add more address spaces without downtime
    //    But you CANNOT shrink or remove in-use ranges
    //
    // 4. AZURE RECOMMENDATION:
    //    Use RFC 1918 private ranges:
    //    - 10.0.0.0/8     (16 million addresses)
    //    - 172.16.0.0/12  (1 million addresses)  
    //    - 192.168.0.0/16 (65,536 addresses)
    // ========================================================================
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    
    // ========================================================================
    // SUBNETS (Inline Definition)
    // ========================================================================
    // Subnets can be defined inline (as here) or as separate resources.
    //
    // INLINE ADVANTAGES:
    // - Deployed atomically with VNet
    // - Simpler template structure
    // - All subnets visible in one place
    //
    // SEPARATE RESOURCE ADVANTAGES:
    // - Can be modified independently
    // - Better for dynamic subnet creation
    // - Required for some delegation scenarios
    //
    // SUBNET NETWORKING FACTS:
    // - Subnets CANNOT span multiple VNets
    // - Subnets CANNOT overlap within a VNet
    // - Minimum subnet size is /29 (8 IPs, 3 usable)
    // - Resources in same subnet can communicate freely (by default)
    // ========================================================================
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        // The subnet's address range - must be within VNet's address space
        addressPrefix: subnet.addressPrefix
        
        // ====================================================================
        // PRIVATE ENDPOINT NETWORK POLICIES
        // ====================================================================
        // By default, NSG rules and UDRs don't apply to private endpoints.
        // Setting this to 'Enabled' allows NSG/UDR to affect private endpoints.
        //
        // Default: Disabled (private endpoints bypass NSG)
        // Set to Enabled if you need to:
        // - Apply NSG rules to private endpoint traffic
        // - Route private endpoint traffic through NVA
        // ====================================================================
        privateEndpointNetworkPolicies: 'Disabled'
        
        // ====================================================================
        // PRIVATE LINK SERVICE NETWORK POLICIES  
        // ====================================================================
        // Similar to above, but for Private Link Services (when YOU are
        // the service provider exposing services via Private Link)
        // ====================================================================
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
    
    // ========================================================================
    // DNS SETTINGS
    // ========================================================================
    // By default, VNets use Azure-provided DNS (168.63.129.16)
    // 
    // This special IP is Azure's internal DNS resolver that:
    // - Resolves Azure internal names (*.internal.cloudapp.net)
    // - Resolves public DNS names
    // - Provides VM name resolution within VNet (when configured)
    //
    // You can override with custom DNS servers:
    // dhcpOptions: {
    //   dnsServers: ['10.0.0.4', '10.0.0.5']  // Your DNS servers
    // }
    //
    // IMPORTANT: Custom DNS affects ALL VMs in the VNet
    // ========================================================================
    // Using default Azure DNS - no dhcpOptions needed
    
    // ========================================================================
    // ENCRYPTION (Preview Feature)
    // ========================================================================
    // VNet encryption encrypts traffic between VMs in the VNet.
    // Requires specific VM SKUs that support accelerated networking.
    // 
    // encryption: {
    //   enabled: true
    //   enforcement: 'AllowUnencrypted' // or 'DropUnencrypted'
    // }
    // ========================================================================
  }
}

// ============================================================================
// NETWORK SECURITY GROUP (Basic)
// ============================================================================
// NSGs will be covered in depth in Module 2.
// This is a minimal NSG to allow SSH access for testing.
// ============================================================================

@description('Basic NSG to allow SSH access to the VM')
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: {
    environment: environmentName
    module: '01-vnet-fundamentals'
  }
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'  // In production, restrict to your IP!
          destinationAddressPrefix: '*'
          description: 'Allow SSH for learning purposes - restrict in production!'
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP ADDRESS
// ============================================================================

@description('Public IP for VM access - in production, use Bastion instead')
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: {
    environment: environmentName
    module: '01-vnet-fundamentals'
  }
  
  // ==========================================================================
  // PUBLIC IP SKU
  // ==========================================================================
  // Standard SKU:
  // - Zone-redundant by default
  // - Static allocation only
  // - Closed to inbound by default (requires NSG)
  // - Required for: Standard Load Balancer, zone-redundant gateways
  //
  // Basic SKU (being deprecated):
  // - No zone redundancy
  // - Dynamic or static allocation
  // - Open to inbound by default
  //
  // NETWORKING IMPACT:
  // Standard Public IPs are more secure (deny by default)
  // and required for production workloads
  // ==========================================================================
  sku: {
    name: 'Standard'
    tier: 'Regional'  // or 'Global' for cross-region scenarios
  }
  
  properties: {
    // Static: IP doesn't change when VM stops (important for DNS)
    // Dynamic: IP may change - only available with Basic SKU
    publicIPAllocationMethod: 'Static'
    
    // IPv4 or IPv6 - most resources still use IPv4
    publicIPAddressVersion: 'IPv4'
    
    // DNS label creates: <label>.<region>.cloudapp.azure.com
    // dnsSettings: {
    //   domainNameLabel: 'myuniquelabel'
    // }
    
    // Idle timeout: How long to keep connection open without traffic
    // Range: 4-30 minutes, Default: 4
    idleTimeoutInMinutes: 4
  }
}

// ============================================================================
// NETWORK INTERFACE (NIC)
// ============================================================================
// The NIC is the connection point between a VM and a VNet.
// It holds the private IP configuration and optionally a public IP.
// ============================================================================

@description('Network interface connecting the VM to the VNet')
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: {
    environment: environmentName
    module: '01-vnet-fundamentals'
  }
  
  properties: {
    // ========================================================================
    // IP CONFIGURATIONS
    // ========================================================================
    // A NIC can have multiple IP configurations for:
    // - Multiple private IPs on same NIC
    // - Load balancer configurations
    // - Application Gateway backend pools
    // ========================================================================
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          // Only one IP config can be primary
          primary: true
          
          // ================================================================
          // PRIVATE IP ADDRESS
          // ================================================================
          // Dynamic: Azure assigns the next available IP
          // Static: You specify the exact IP (must be available)
          //
          // WHICH TO USE?
          // - Dynamic: Most workloads (IP assigned at NIC creation)
          // - Static: Domain controllers, DNS servers, apps needing fixed IP
          //
          // NOTE: Even with Dynamic, the IP rarely changes - only when:
          // - NIC is deleted and recreated
          // - Subnet is changed
          // ================================================================
          privateIPAllocationMethod: 'Dynamic'
          // To use static: 
          // privateIPAllocationMethod: 'Static'
          // privateIPAddress: '10.0.1.10'  // Must be available in subnet
          
          // ================================================================
          // SUBNET ASSOCIATION
          // ================================================================
          // This is where the NIC connects to the VNet.
          // The subnet determines:
          // - Available IP range for this NIC
          // - NSG rules (if NSG attached to subnet)
          // - Route table (if UDR attached to subnet)
          // - Service endpoints available
          // ================================================================
          subnet: {
            // Reference the web subnet from our VNet
            // Using array index 0 because snet-web is first in our array
            id: virtualNetwork.properties.subnets[0].id
          }
          
          // ================================================================
          // PUBLIC IP ASSOCIATION (Optional)
          // ================================================================
          // Associates a public IP with this NIC for direct internet access.
          // 
          // ALTERNATIVES TO PUBLIC IP:
          // - Azure Bastion (secure remote access)
          // - Azure Firewall DNAT (centralized ingress)
          // - Load Balancer (for web workloads)
          // - NAT Gateway (for outbound only)
          // ================================================================
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    
    // ========================================================================
    // NSG ASSOCIATION
    // ========================================================================
    // NSG can be attached at NIC level, subnet level, or both.
    // When both are attached:
    // - Inbound: Subnet NSG evaluated first, then NIC NSG
    // - Outbound: NIC NSG evaluated first, then Subnet NSG
    //
    // BEST PRACTICE: Use subnet-level NSGs for shared rules,
    // NIC-level for VM-specific exceptions
    // ========================================================================
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    
    // ========================================================================
    // ACCELERATED NETWORKING
    // ========================================================================
    // SR-IOV technology that bypasses the Azure host for network traffic.
    // Benefits:
    // - Lower latency
    // - Higher throughput
    // - More consistent performance
    //
    // Requirements:
    // - Supported VM sizes (most D/E/F series)
    // - Supported OS (Windows Server 2012 R2+, Ubuntu 14.04+)
    //
    // STRONGLY RECOMMENDED for production workloads
    // ========================================================================
    enableAcceleratedNetworking: true
    
    // ========================================================================
    // IP FORWARDING
    // ========================================================================
    // Must be enabled for NVAs (firewalls, routers) that forward traffic.
    // Normal VMs should have this disabled.
    //
    // Use case: When this NIC receives traffic destined for another IP
    // and needs to forward it (like a router does)
    // ========================================================================
    enableIPForwarding: false
  }
}

// ============================================================================
// VIRTUAL MACHINE
// ============================================================================
// A simple Linux VM for testing network connectivity.
// VM details are not the focus of this module.
// ============================================================================

@description('Linux VM for testing network connectivity')
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: {
    environment: environmentName
    module: '01-vnet-fundamentals'
  }
  
  properties: {
    hardwareProfile: {
      // D2s_v3: 2 vCPU, 8 GB RAM - small but supports accelerated networking
      vmSize: 'Standard_D2s_v3'
    }
    
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${vmName}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    
    // ========================================================================
    // NETWORK PROFILE
    // ========================================================================
    // This is where the VM connects to the network via NIC(s).
    // A VM can have multiple NICs for:
    // - Multiple subnet connectivity
    // - Network virtual appliance scenarios
    // - Separation of management and data traffic
    // ========================================================================
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            primary: true
          }
        }
      ]
    }
    
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        // Using managed storage - no storage account needed
      }
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
// Outputs help with:
// - Chaining deployments
// - Getting resource information post-deployment
// - Debugging and verification
// ============================================================================

@description('The resource ID of the Virtual Network')
output vnetId string = virtualNetwork.id

@description('The name of the Virtual Network')
output vnetName string = virtualNetwork.name

@description('The address space of the Virtual Network')
output vnetAddressSpace array = virtualNetwork.properties.addressSpace.addressPrefixes

@description('List of subnet names and their address prefixes')
output subnets array = [for (subnet, i) in subnets: {
  name: virtualNetwork.properties.subnets[i].name
  addressPrefix: virtualNetwork.properties.subnets[i].properties.addressPrefix
  id: virtualNetwork.properties.subnets[i].id
}]

@description('The private IP address assigned to the VM')
output vmPrivateIp string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

@description('The public IP address assigned to the VM')
output vmPublicIp string = publicIp.properties.ipAddress

@description('SSH command to connect to the VM')
output sshCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'

// ============================================================================
// NETWORKING REVIEW
// ============================================================================
// After deploying this template, verify you understand:
//
// 1. ADDRESS SPACE: Why we chose 10.0.0.0/16
// 2. SUBNET LAYOUT: Purpose of each subnet tier
// 3. RESERVED IPS: Why the VM got .4 not .1
// 4. NIC-SUBNET LINK: How the NIC references the subnet
// 5. PUBLIC vs PRIVATE IP: When to use each
// 6. SYSTEM ROUTES: What routes Azure creates automatically
//
// NEXT MODULE PREVIEW:
// In Module 2, we'll add NSGs to control traffic between subnets
// and learn about security rule evaluation order.
// ============================================================================
