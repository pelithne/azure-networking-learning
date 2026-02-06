// ============================================================================
// Module 3: VNet Peering
// ============================================================================
// This template deploys a hub-spoke topology to demonstrate VNet peering
// concepts including non-transitivity, peering properties, and state management.
//
// NETWORKING CONCEPTS COVERED:
// - VNet peering types (regional)
// - Peering properties (allowForwardedTraffic, allowVnetAccess)
// - Non-transitive nature of peering
// - Bidirectional peering requirements
// - Effective routes with peering
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

// ----------------------------------------------------------------------------
// VARIABLES
// ----------------------------------------------------------------------------

// ============================================================================
// VNET ADDRESS PLANNING
// ============================================================================
// For peering, address spaces MUST NOT overlap.
// We use three distinct /16 ranges:
//
//   Hub:    10.0.0.0/16
//   Spoke1: 10.1.0.0/16
//   Spoke2: 10.2.0.0/16
//
// This follows common enterprise patterns where each VNet owns a /16.
// ============================================================================

var vnets = {
  hub: {
    name: 'vnet-hub'
    addressSpace: '10.0.0.0/16'
    subnetPrefix: '10.0.1.0/24'
    subnetName: 'snet-workload'
  }
  spoke1: {
    name: 'vnet-spoke1'
    addressSpace: '10.1.0.0/16'
    subnetPrefix: '10.1.1.0/24'
    subnetName: 'snet-workload'
  }
  spoke2: {
    name: 'vnet-spoke2'
    addressSpace: '10.2.0.0/16'
    subnetPrefix: '10.2.1.0/24'
    subnetName: 'snet-workload'
  }
}

// VM configuration
var vmSize = 'Standard_B2s'
var vmImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// ============================================================================
// NETWORK SECURITY GROUPS
// ============================================================================
// Simple NSG allowing SSH and ICMP for testing

resource nsgHub 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-hub'
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
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Allow ping within VNet and peered VNets'
        }
      }
    ]
  }
}

resource nsgSpoke1 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke1'
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
          sourceAddressPrefix: 'VirtualNetwork'
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
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgSpoke2 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke2'
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
          sourceAddressPrefix: 'VirtualNetwork'
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
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ============================================================================
// VIRTUAL NETWORKS
// ============================================================================

resource vnetHub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnets.hub.name
  location: location
  tags: {
    role: 'hub'
    module: '03-vnet-peering'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [vnets.hub.addressSpace]
    }
    subnets: [
      {
        name: vnets.hub.subnetName
        properties: {
          addressPrefix: vnets.hub.subnetPrefix
          networkSecurityGroup: {
            id: nsgHub.id
          }
        }
      }
    ]
  }
}

resource vnetSpoke1 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnets.spoke1.name
  location: location
  tags: {
    role: 'spoke'
    module: '03-vnet-peering'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [vnets.spoke1.addressSpace]
    }
    subnets: [
      {
        name: vnets.spoke1.subnetName
        properties: {
          addressPrefix: vnets.spoke1.subnetPrefix
          networkSecurityGroup: {
            id: nsgSpoke1.id
          }
        }
      }
    ]
  }
}

resource vnetSpoke2 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnets.spoke2.name
  location: location
  tags: {
    role: 'spoke'
    module: '03-vnet-peering'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [vnets.spoke2.addressSpace]
    }
    subnets: [
      {
        name: vnets.spoke2.subnetName
        properties: {
          addressPrefix: vnets.spoke2.subnetPrefix
          networkSecurityGroup: {
            id: nsgSpoke2.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// VNET PEERING
// ============================================================================
// CRITICAL CONCEPT: Peering must be created on BOTH sides.
// If only one side creates it, peering state will be "Initiated" and 
// traffic will NOT flow.
//
// PEERING PROPERTIES EXPLAINED:
//
// allowVirtualNetworkAccess (default: true)
//   - Allows VMs in peered VNet to communicate
//   - Set to false to peer but block traffic (unusual)
//
// allowForwardedTraffic (default: false)
//   - Allows traffic forwarded BY the peer VNet (not originated there)
//   - Required for NVA/Firewall scenarios
//   - Example: Hub has firewall, spoke1 sends traffic to spoke2 via firewall
//     Spoke2 must allowForwardedTraffic from Hub
//
// allowGatewayTransit (default: false)
//   - "I have a gateway, peers can use it"
//   - Set on the VNet that HAS the VPN/ExpressRoute gateway
//
// useRemoteGateways (default: false)
//   - "I want to use my peer's gateway"
//   - Set on the VNet that NEEDS to use the gateway
//   - Cannot be true if this VNet already has its own gateway
//
// DIAGRAM:
//                    allowGatewayTransit=true
//                    ┌──────────────────────┐
//                    │       Hub VNet       │
//   On-Prem ◄──────► │  [VPN Gateway]       │
//                    └──────────────────────┘
//                              ▲
//                              │ peering
//                              ▼
//                    useRemoteGateways=true
//                    ┌──────────────────────┐
//                    │     Spoke VNet       │
//                    │  (no gateway)        │
//                    └──────────────────────┘
// ============================================================================

// ----------------------------------------------------------------------------
// Hub to Spoke1 Peering
// ----------------------------------------------------------------------------
resource peeringHubToSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-spoke1'
  properties: {
    // ========================================================================
    // PEERING CONFIGURATION
    // ========================================================================
    
    // The remote VNet to peer with
    remoteVirtualNetwork: {
      id: vnetSpoke1.id
    }
    
    // Allow VMs in Hub to communicate with VMs in Spoke1
    // If false: peering exists but traffic is blocked
    allowVirtualNetworkAccess: true
    
    // ========================================================================
    // FORWARDED TRAFFIC
    // ========================================================================
    // Allow Hub to receive traffic that was forwarded by Spoke1
    // This is needed when Spoke1 has an NVA that forwards traffic
    // In our simple case, we enable it for future flexibility
    allowForwardedTraffic: true
    
    // ========================================================================
    // GATEWAY TRANSIT (for future module)
    // ========================================================================
    // If Hub had a VPN Gateway, we'd set allowGatewayTransit: true
    // This would allow Spoke1 to use Hub's gateway to reach on-premises
    // 
    // We set it to false since we don't have a gateway yet
    // (Module 4 will add VPN Gateway)
    allowGatewayTransit: false
    
    // Hub doesn't use anyone else's gateway
    useRemoteGateways: false
  }
}

// ----------------------------------------------------------------------------
// Spoke1 to Hub Peering (REQUIRED - must be bidirectional)
// ----------------------------------------------------------------------------
resource peeringSpoke1ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpoke1
  name: 'spoke1-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    
    // Spoke doesn't have a gateway to share
    allowGatewayTransit: false
    
    // When Hub has a gateway, change this to true
    // so Spoke1 can reach on-premises through Hub
    useRemoteGateways: false
  }
}

// ----------------------------------------------------------------------------
// Hub to Spoke2 Peering
// ----------------------------------------------------------------------------
resource peeringHubToSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: {
      id: vnetSpoke2.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ----------------------------------------------------------------------------
// Spoke2 to Hub Peering
// ----------------------------------------------------------------------------
resource peeringSpoke2ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpoke2
  name: 'spoke2-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ============================================================================
// NOTE: NO SPOKE1 ↔ SPOKE2 PEERING
// ============================================================================
// We intentionally DO NOT create peering between Spoke1 and Spoke2.
// This demonstrates the NON-TRANSITIVE nature of peering:
//
//   Spoke1 ↔ Hub ↔ Spoke2
//
//   Spoke1 CAN reach Hub ✓
//   Hub CAN reach Spoke2 ✓
//   Spoke1 CANNOT reach Spoke2 directly ✗
//
// To enable Spoke1 ↔ Spoke2 communication, you would need either:
// 1. Direct peering between Spoke1 and Spoke2
// 2. An NVA/Firewall in Hub with UDRs to route traffic through it
// 3. Azure Virtual WAN (manages this automatically)
// ============================================================================

// ============================================================================
// PUBLIC IP (for Hub VM SSH access)
// ============================================================================

resource publicIpHub 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-hub'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// NETWORK INTERFACES
// ============================================================================

resource nicHub 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-hub'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetHub.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIpHub.id
          }
        }
      }
    ]
  }
}

resource nicSpoke1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-spoke1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetSpoke1.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource nicSpoke2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-spoke2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetSpoke2.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

// ============================================================================
// VIRTUAL MACHINES
// ============================================================================

resource vmHub 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-hub'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-hub'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: vmImage
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
          id: nicHub.id
        }
      ]
    }
  }
}

resource vmSpoke1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke1'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-spoke1'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: vmImage
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
          id: nicSpoke1.id
        }
      ]
    }
  }
}

resource vmSpoke2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke2'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'vm-spoke2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: vmImage
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
          id: nicSpoke2.id
        }
      ]
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Hub VM public IP for SSH')
output hubPublicIp string = publicIpHub.properties.ipAddress

@description('SSH command')
output sshCommand string = 'ssh ${adminUsername}@${publicIpHub.properties.ipAddress}'

@description('VM private IPs for testing')
output vmIps object = {
  hub: nicHub.properties.ipConfigurations[0].properties.privateIPAddress
  spoke1: nicSpoke1.properties.ipConfigurations[0].properties.privateIPAddress
  spoke2: nicSpoke2.properties.ipConfigurations[0].properties.privateIPAddress
}

@description('Peering status - verify both show Connected')
output peeringInfo array = [
  {
    name: peeringHubToSpoke1.name
    state: peeringHubToSpoke1.properties.peeringState
    remoteVNet: vnets.spoke1.name
  }
  {
    name: peeringSpoke1ToHub.name
    state: peeringSpoke1ToHub.properties.peeringState
    remoteVNet: vnets.hub.name
  }
  {
    name: peeringHubToSpoke2.name
    state: peeringHubToSpoke2.properties.peeringState
    remoteVNet: vnets.spoke2.name
  }
  {
    name: peeringSpoke2ToHub.name
    state: peeringSpoke2ToHub.properties.peeringState
    remoteVNet: vnets.hub.name
  }
]

// ============================================================================
// CONNECTIVITY MATRIX
// ============================================================================
//
//              │  Hub  │ Spoke1 │ Spoke2 │
//  ────────────┼───────┼────────┼────────┤
//    Hub       │   -   │   ✓    │   ✓    │
//    Spoke1    │   ✓   │   -    │   ✗    │  ← Non-transitive!
//    Spoke2    │   ✓   │   ✗    │   -    │  ← Non-transitive!
//
// ============================================================================
