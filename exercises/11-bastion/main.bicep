// Module 11: Azure Bastion
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// ============================================================================
// VIRTUAL NETWORK WITH BASTION SUBNET
// ============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-main'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      // ====================================================================
      // AZURE BASTION SUBNET
      // - Name MUST be 'AzureBastionSubnet' (case-sensitive)
      // - Minimum /26 for Basic/Standard SKU
      // - Bastion uses this to connect to VMs in other subnets
      // ====================================================================
      { name: 'AzureBastionSubnet', properties: { addressPrefix: '10.0.0.0/26' } }
      { name: 'snet-workload', properties: { addressPrefix: '10.0.1.0/24' } }
    ]
  }
}

// ============================================================================
// BASTION PUBLIC IP
// Must be Standard SKU and Static allocation
// ============================================================================
resource pipBastion 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-bastion'
  location: location
  sku: { name: 'Standard' }  // Required: Standard SKU
  properties: {
    publicIPAllocationMethod: 'Static'  // Required: Static
  }
}

// ============================================================================
// AZURE BASTION
// ============================================================================
resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: 'bas-hub'
  location: location
  sku: {
    name: 'Standard'  // Standard enables native client support
  }
  properties: {
    // Standard SKU features
    enableTunneling: true  // Native client support
    enableFileCopy: true   // File transfer via portal
    enableIpConnect: true  // Connect by IP (not just resource ID)
    
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        // Bastion must be in AzureBastionSubnet
        subnet: { id: '${vnet.id}/subnets/AzureBastionSubnet' }
        publicIPAddress: { id: pipBastion.id }
      }
    }]
  }
}

// ============================================================================
// WORKLOAD VM (No Public IP!)
// ============================================================================
resource nicVm 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: '${vnet.id}/subnets/snet-workload' }
        // NO public IP - this VM is only accessible via Bastion
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-workload'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'vm-workload'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nicVm.id }] }
  }
}

output bastionName string = bastion.name
output vmName string = vm.name
output connectViaPortal string = 'Azure Portal → ${vm.name} → Connect → Bastion'
output nativeClientCommand string = 'az network bastion ssh -n ${bastion.name} -g ${resourceGroup().name} --target-resource-id ${vm.id} --auth-type password --username ${adminUsername}'
