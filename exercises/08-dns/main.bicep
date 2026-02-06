// Module 8: DNS & Name Resolution
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

var privateDnsZoneName = 'contoso.internal'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-dns'
  location: location
  properties: {
    securityRules: [
      { name: 'AllowSSH', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '22' } }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-dns'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [{ name: 'snet-default', properties: { addressPrefix: '10.0.1.0/24', networkSecurityGroup: { id: nsg.id } } }]
  }
}

// ============================================================================
// PRIVATE DNS ZONE
// ============================================================================
// Provides name resolution within linked VNets
// Zone names can be:
// - Custom (contoso.internal)
// - Azure service (privatelink.*.core.windows.net for private endpoints)
// ============================================================================
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'  // Always global
}

// ============================================================================
// VNET LINK
// ============================================================================
// Links the DNS zone to a VNet for resolution
// registrationEnabled: Auto-register VM names
// ============================================================================
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-vnet-dns'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: true  // Auto-register VM names
  }
}

// Manual DNS records
resource aRecord 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  parent: privateDnsZone
  name: 'db'
  properties: {
    ttl: 300
    aRecords: [{ ipv4Address: '10.0.1.100' }]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: '${vnet.id}/subnets/snet-default' }
        publicIPAddress: { id: publicIp.id }
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-dns-test'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-dns-test', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}

output vmPublicIp string = publicIp.properties.ipAddress
output privateDnsZone string = privateDnsZoneName
output testCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress} "nslookup vm-dns-test.${privateDnsZoneName}"'
