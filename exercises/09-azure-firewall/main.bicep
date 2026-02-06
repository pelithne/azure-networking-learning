// Module 9: Azure Firewall
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// Hub VNet with Firewall
resource vnetHub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      // ====================================================================
      // AZURE FIREWALL SUBNET
      // Name MUST be 'AzureFirewallSubnet' - Azure requirement
      // Minimum size: /26 (64 IPs)
      // ====================================================================
      { name: 'AzureFirewallSubnet', properties: { addressPrefix: '10.0.0.0/26' } }
      { name: 'AzureFirewallManagementSubnet', properties: { addressPrefix: '10.0.0.64/26' } }
    ]
  }
}

// Spoke VNet
resource nsgSpoke 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke'
  location: location
  properties: { securityRules: [{ name: 'AllowSSH', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '22' } }] }
}

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.1.1.0/24', networkSecurityGroup: { id: nsgSpoke.id } } }]
  }
}

// Peering
resource peeringHubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-spoke'
  properties: { remoteVirtualNetwork: { id: vnetSpoke.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

resource peeringSpokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpoke
  name: 'spoke-to-hub'
  properties: { remoteVirtualNetwork: { id: vnetHub.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

// Firewall Public IPs
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

// ============================================================================
// FIREWALL POLICY
// ============================================================================
// Policies define rules and can be shared across firewalls
// ============================================================================
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-09-01' = {
  name: 'policy-firewall'
  location: location
  properties: {
    sku: { tier: 'Standard' }
    threatIntelMode: 'Alert'
  }
}

// Rule Collection Group
resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-09-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleGroup'
  properties: {
    priority: 100
    ruleCollections: [
      // Network Rules (L3/L4)
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          { ruleType: 'NetworkRule', name: 'AllowDNS', ipProtocols: ['UDP'], sourceAddresses: ['10.1.0.0/16'], destinationAddresses: ['*'], destinationPorts: ['53'] }
        ]
      }
      // Application Rules (L7 FQDN)
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApplicationRules'
        priority: 200
        action: { type: 'Allow' }
        rules: [
          { ruleType: 'ApplicationRule', name: 'AllowMicrosoft', sourceAddresses: ['10.1.0.0/16'], protocols: [{ protocolType: 'Https', port: 443 }], targetFqdns: ['*.microsoft.com', '*.azure.com'] }
        ]
      }
    ]
  }
}

// ============================================================================
// AZURE FIREWALL
// ============================================================================
resource firewall 'Microsoft.Network/azureFirewalls@2023-09-01' = {
  name: 'fw-hub'
  location: location
  properties: {
    sku: { name: 'AZFW_VNet', tier: 'Standard' }
    firewallPolicy: { id: firewallPolicy.id }
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: '${vnetHub.id}/subnets/AzureFirewallSubnet' }
        publicIPAddress: { id: pipFirewall.id }
      }
    }]
    managementIpConfiguration: {
      name: 'mgmt-ipconfig'
      properties: {
        subnet: { id: '${vnetHub.id}/subnets/AzureFirewallManagementSubnet' }
        publicIPAddress: { id: pipFirewallMgmt.id }
      }
    }
  }
}

// Route Table to force traffic through firewall
resource routeTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke-to-firewall'
  location: location
  properties: {
    routes: [{
      name: 'ToInternet'
      properties: {
        addressPrefix: '0.0.0.0/0'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
      }
    }]
  }
}

// Associate route table with spoke subnet
resource spokeSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnetSpoke
  name: 'snet-workload'
  properties: {
    addressPrefix: '10.1.1.0/24'
    networkSecurityGroup: { id: nsgSpoke.id }
    routeTable: { id: routeTable.id }
  }
  dependsOn: [peeringSpokeToHub]
}

// Test VM in spoke
resource pipVm 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nicVm 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: '${vnetSpoke.id}/subnets/snet-workload' }
        publicIPAddress: { id: pipVm.id }
      }
    }]
  }
  dependsOn: [spokeSubnetUpdate]
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-spoke', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nicVm.id }] }
  }
}

output vmPublicIp string = pipVm.properties.ipAddress
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output testCommand string = 'ssh ${adminUsername}@${pipVm.properties.ipAddress} "curl -I https://www.microsoft.com"'
