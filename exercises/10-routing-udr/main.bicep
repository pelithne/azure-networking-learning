// Module 10: Routing & User Defined Routes
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// ============================================================================
// HUB VNET - Contains the Network Virtual Appliance (NVA)
// ============================================================================
resource vnetHub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [{ name: 'snet-nva', properties: { addressPrefix: '10.0.1.0/24' } }]
  }
}

// ============================================================================
// SPOKE VNETS - Traffic will be forced through NVA
// ============================================================================
resource nsgSpoke 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spoke'
  location: location
  properties: { securityRules: [{ name: 'AllowSSH', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '22' } }] }
}

resource vnetSpokeA 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-a'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.1.1.0/24', networkSecurityGroup: { id: nsgSpoke.id } } }]
  }
}

resource vnetSpokeB 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-b'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.2.1.0/24', networkSecurityGroup: { id: nsgSpoke.id } } }]
  }
}

// ============================================================================
// VNET PEERING - Hub-Spoke Topology
// ============================================================================
resource peeringHubToA 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-spoke-a'
  properties: { remoteVirtualNetwork: { id: vnetSpokeA.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

resource peeringAToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeA
  name: 'spoke-a-to-hub'
  properties: { remoteVirtualNetwork: { id: vnetHub.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

resource peeringHubToB 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetHub
  name: 'hub-to-spoke-b'
  properties: { remoteVirtualNetwork: { id: vnetSpokeB.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

resource peeringBToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: vnetSpokeB
  name: 'spoke-b-to-hub'
  properties: { remoteVirtualNetwork: { id: vnetHub.id }, allowForwardedTraffic: true, allowVirtualNetworkAccess: true }
}

// ============================================================================
// NVA (Network Virtual Appliance) - Simple Linux VM with IP Forwarding
// ============================================================================
resource nicNva 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-nva'
  location: location
  properties: {
    // IP FORWARDING - Required for NVA to route traffic
    // Without this, Azure drops packets not destined for this NIC
    enableIPForwarding: true
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Static'
        privateIPAddress: '10.0.1.4'
        subnet: { id: '${vnetHub.id}/subnets/snet-nva' }
      }
    }]
  }
}

resource vmNva 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-nva'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'vm-nva'
      adminUsername: adminUsername
      adminPassword: adminPassword
      // Enable OS-level IP forwarding via cloud-init
      customData: base64('#!/bin/bash\nsysctl -w net.ipv4.ip_forward=1\necho "net.ipv4.ip_forward=1" >> /etc/sysctl.conf')
    }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nicNva.id }] }
  }
}

// ============================================================================
// ROUTE TABLES (UDRs)
// Force spoke-to-spoke traffic through NVA
// ============================================================================
resource rtSpokeA 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke-a'
  location: location
  properties: {
    // disableBgpRoutePropagation: false (default)
    // BGP routes from gateways will still be learned
    routes: [{
      name: 'ToSpokeB-via-NVA'
      properties: {
        addressPrefix: '10.2.0.0/16'  // Spoke B range
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: '10.0.1.4'  // NVA IP
      }
    }]
  }
}

resource rtSpokeB 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke-b'
  location: location
  properties: {
    routes: [{
      name: 'ToSpokeA-via-NVA'
      properties: {
        addressPrefix: '10.1.0.0/16'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: '10.0.1.4'
      }
    }]
  }
}

// Associate route tables with subnets
resource spokeASubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnetSpokeA
  name: 'snet-workload'
  properties: {
    addressPrefix: '10.1.1.0/24'
    networkSecurityGroup: { id: nsgSpoke.id }
    routeTable: { id: rtSpokeA.id }
  }
  dependsOn: [peeringAToHub]
}

resource spokeBSubnetUpdate 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  parent: vnetSpokeB
  name: 'snet-workload'
  properties: {
    addressPrefix: '10.2.1.0/24'
    networkSecurityGroup: { id: nsgSpoke.id }
    routeTable: { id: rtSpokeB.id }
  }
  dependsOn: [peeringBToHub]
}

// Test VMs in spokes (with public IPs for SSH access)
resource pipVmA 'Microsoft.Network/publicIPAddresses@2023-09-01' = { name: 'pip-vm-a', location: location, sku: { name: 'Standard' }, properties: { publicIPAllocationMethod: 'Static' } }
resource pipVmB 'Microsoft.Network/publicIPAddresses@2023-09-01' = { name: 'pip-vm-b', location: location, sku: { name: 'Standard' }, properties: { publicIPAllocationMethod: 'Static' } }

resource nicVmA 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-a'
  location: location
  properties: { ipConfigurations: [{ name: 'ipconfig1', properties: { privateIPAllocationMethod: 'Static', privateIPAddress: '10.1.1.4', subnet: { id: '${vnetSpokeA.id}/subnets/snet-workload' }, publicIPAddress: { id: pipVmA.id } } }] }
  dependsOn: [spokeASubnetUpdate]
}

resource nicVmB 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-b'
  location: location
  properties: { ipConfigurations: [{ name: 'ipconfig1', properties: { privateIPAllocationMethod: 'Static', privateIPAddress: '10.2.1.4', subnet: { id: '${vnetSpokeB.id}/subnets/snet-workload' }, publicIPAddress: { id: pipVmB.id } } }] }
  dependsOn: [spokeBSubnetUpdate]
}

resource vmA 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke-a'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-spoke-a', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: { imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }, osDisk: { createOption: 'FromImage' } }
    networkProfile: { networkInterfaces: [{ id: nicVmA.id }] }
  }
}

resource vmB 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke-b'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-spoke-b', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: { imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }, osDisk: { createOption: 'FromImage' } }
    networkProfile: { networkInterfaces: [{ id: nicVmB.id }] }
  }
}

output vmAPublicIp string = pipVmA.properties.ipAddress
output vmBPublicIp string = pipVmB.properties.ipAddress
output nvaPrivateIp string = '10.0.1.4'
output testFromA string = 'ssh ${adminUsername}@${pipVmA.properties.ipAddress} "traceroute 10.2.1.4"'
