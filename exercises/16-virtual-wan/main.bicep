// Module 16: Virtual WAN (Optional Lab - Expensive!)
// ⚠️  This deployment costs ~$2-5/hour minimum
// Only deploy if you want hands-on experience and are willing to pay

param location string = 'eastus2'

// ============================================================================
// VIRTUAL WAN
// The parent resource for all vWAN components
// ============================================================================
resource virtualWan 'Microsoft.Network/virtualWans@2023-09-01' = {
  name: 'vwan-learn'
  location: location
  properties: {
    type: 'Standard'  // Standard required for ExpressRoute, P2S, inter-hub
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true  // Enables branch-to-branch via hub
  }
}

// ============================================================================
// VIRTUAL HUB
// Microsoft-managed hub in a region
// ============================================================================
resource virtualHub 'Microsoft.Network/virtualHubs@2023-09-01' = {
  name: 'vhub-${location}'
  location: location
  properties: {
    virtualWan: { id: virtualWan.id }
    addressPrefix: '10.100.0.0/24'  // Hub's address space (managed by Azure)
    
    // Hub routing preference
    hubRoutingPreference: 'ExpressRoute'  // or 'VpnGateway', 'ASPath'
  }
}

// ============================================================================
// SPOKE VNETS
// These will connect to the Virtual Hub
// ============================================================================
resource vnetSpoke1 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-1'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.1.1.0/24' } }]
  }
}

resource vnetSpoke2 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-2'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.2.1.0/24' } }]
  }
}

// ============================================================================
// HUB VNET CONNECTIONS
// Connect spoke VNets to the Virtual Hub
// ============================================================================
resource hubConnectionSpoke1 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-09-01' = {
  parent: virtualHub
  name: 'conn-spoke-1'
  properties: {
    remoteVirtualNetwork: { id: vnetSpoke1.id }
    enableInternetSecurity: true  // Apply hub's security policies
  }
}

resource hubConnectionSpoke2 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-09-01' = {
  parent: virtualHub
  name: 'conn-spoke-2'
  properties: {
    remoteVirtualNetwork: { id: vnetSpoke2.id }
    enableInternetSecurity: true
  }
}

// Note: VPN Gateway and other costly components are not deployed by default
// You can add them manually in the portal to explore further

output virtualWanName string = virtualWan.name
output virtualHubName string = virtualHub.name
output spoke1Name string = vnetSpoke1.name
output spoke2Name string = vnetSpoke2.name
output hubIP string = virtualHub.properties.addressPrefix
output warning string = '⚠️  Remember to delete this deployment when done - it costs money!'
