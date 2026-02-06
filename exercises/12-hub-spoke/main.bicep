// Module 12: Hub-Spoke Architecture
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// ============================================================================
// HUB VNET - Central network with shared services
// ============================================================================
resource vnetHub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      { name: 'AzureFirewallSubnet', properties: { addressPrefix: '10.0.0.0/26' } }
      { name: 'AzureFirewallManagementSubnet', properties: { addressPrefix: '10.0.0.64/26' } }
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.0.1.0/26' } }
      { name: 'snet-shared', properties: { addressPrefix: '10.0.2.0/24' } }
    ]
  }
}

// ============================================================================
// SPOKE VNETS - Workload networks
// ============================================================================
resource nsgSpoke 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke'
  location: location
  properties: { securityRules: [] }  // Traffic controlled by firewall
}

resource vnetSpokeWeb 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-web'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [{ name: 'snet-web', properties: { addressPrefix: '10.1.1.0/24', networkSecurityGroup: { id: nsgSpoke.id } } }]
  }
}

resource vnetSpokeApp 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-app'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [{ name: 'snet-app', properties: { addressPrefix: '10.2.1.0/24', networkSecurityGroup: { id: nsgSpoke.id } } }]
  }
}

// ============================================================================
// VNET PEERING - Hub-Spoke Topology
// ============================================================================
resource peeringHubToWeb 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-web'
  properties: {
    remoteVirtualNetwork: { id: vnetSpokeWeb.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    // allowGatewayTransit: true  // Enable when hub has gateway
  }
}

resource peeringWebToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeWeb
  name: 'web-to-hub'
  properties: {
    remoteVirtualNetwork: { id: vnetHub.id }
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    // useRemoteGateways: true  // Enable to use hub's gateway
  }
}

resource peeringHubToApp 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-app'
  properties: { remoteVirtualNetwork: { id: vnetSpokeApp.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

resource peeringAppToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeApp
  name: 'app-to-hub'
  properties: { remoteVirtualNetwork: { id: vnetHub.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

// ============================================================================
// AZURE FIREWALL - Central security point
// ============================================================================
resource pipFirewall 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-firewall'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource pipFirewallMgmt 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-firewall-mgmt'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
  name: 'policy-hub-firewall'
  location: location
  properties: { sku: { tier: 'Standard' }, threatIntelMode: 'Alert' }
}

resource ruleGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: firewallPolicy
  name: 'HubSpokeRules'
  properties: {
    priority: 100
    ruleCollections: [
      // Allow spoke-to-spoke traffic
      { ruleCollectionType: 'FirewallPolicyFilterRuleCollection', name: 'AllowSpokes', priority: 100, action: { type: 'Allow' }, rules: [
        { ruleType: 'NetworkRule', name: 'WebToApp', ipProtocols: ['TCP'], sourceAddresses: ['10.1.0.0/16'], destinationAddresses: ['10.2.0.0/16'], destinationPorts: ['80', '443', '8080'] }
        { ruleType: 'NetworkRule', name: 'AppToWeb', ipProtocols: ['TCP'], sourceAddresses: ['10.2.0.0/16'], destinationAddresses: ['10.1.0.0/16'], destinationPorts: ['80', '443'] }
      ]}
      // Allow outbound internet for updates
      { ruleCollectionType: 'FirewallPolicyFilterRuleCollection', name: 'AllowInternet', priority: 200, action: { type: 'Allow' }, rules: [
        { ruleType: 'ApplicationRule', name: 'AllowUpdates', sourceAddresses: ['10.0.0.0/8'], protocols: [{ protocolType: 'Https', port: 443 }], targetFqdns: ['*.ubuntu.com', '*.microsoft.com'] }
      ]}
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: 'fw-hub'
  location: location
  properties: {
    sku: { name: 'AZFW_VNet', tier: 'Standard' }
    firewallPolicy: { id: firewallPolicy.id }
    ipConfigurations: [{ name: 'ipconfig1', properties: { subnet: { id: '${vnetHub.id}/subnets/AzureFirewallSubnet' }, publicIPAddress: { id: pipFirewall.id } } }]
    managementIpConfiguration: { name: 'mgmt', properties: { subnet: { id: '${vnetHub.id}/subnets/AzureFirewallManagementSubnet' }, publicIPAddress: { id: pipFirewallMgmt.id } } }
  }
}

// ============================================================================
// ROUTE TABLES - Force traffic through firewall
// ============================================================================
resource rtSpoke 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke-to-firewall'
  location: location
  properties: {
    routes: [
      { name: 'ToInternet', properties: { addressPrefix: '0.0.0.0/0', nextHopType: 'VirtualAppliance', nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress } }
      { name: 'ToOtherSpokes', properties: { addressPrefix: '10.0.0.0/8', nextHopType: 'VirtualAppliance', nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress } }
    ]
  }
}

// Update spoke subnets with route table
resource webSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnetSpokeWeb
  name: 'snet-web'
  properties: { addressPrefix: '10.1.1.0/24', networkSecurityGroup: { id: nsgSpoke.id }, routeTable: { id: rtSpoke.id } }
  dependsOn: [peeringWebToHub]
}

resource appSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnetSpokeApp
  name: 'snet-app'
  properties: { addressPrefix: '10.2.1.0/24', networkSecurityGroup: { id: nsgSpoke.id }, routeTable: { id: rtSpoke.id } }
  dependsOn: [peeringAppToHub]
}

// ============================================================================
// AZURE BASTION - Secure management access
// ============================================================================
resource pipBastion 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-bastion'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: 'bas-hub'
  location: location
  sku: { name: 'Standard' }
  properties: {
    enableTunneling: true
    ipConfigurations: [{ name: 'ipconfig1', properties: { subnet: { id: '${vnetHub.id}/subnets/AzureBastionSubnet' }, publicIPAddress: { id: pipBastion.id } } }]
  }
}

// ============================================================================
// WORKLOAD VMs (No public IPs - accessed via Bastion)
// ============================================================================
resource nicWeb 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-web'
  location: location
  properties: { ipConfigurations: [{ name: 'ipconfig1', properties: { subnet: { id: '${vnetSpokeWeb.id}/subnets/snet-web' } } }] }
  dependsOn: [webSubnetUpdate]
}

resource nicApp 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-app'
  location: location
  properties: { ipConfigurations: [{ name: 'ipconfig1', properties: { subnet: { id: '${vnetSpokeApp.id}/subnets/snet-app' } } }] }
  dependsOn: [appSubnetUpdate]
}

resource vmWeb 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-web'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-web', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: { imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }, osDisk: { createOption: 'FromImage' } }
    networkProfile: { networkInterfaces: [{ id: nicWeb.id }] }
  }
}

resource vmApp 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-app'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-app', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: { imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }, osDisk: { createOption: 'FromImage' } }
    networkProfile: { networkInterfaces: [{ id: nicApp.id }] }
  }
}

output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output connectViaBastion string = 'Azure Portal → vm-web or vm-app → Connect → Bastion'
