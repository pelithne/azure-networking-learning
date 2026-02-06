// Module 14: Network Monitoring & Diagnostics
param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// ============================================================================
// NETWORK WATCHER
// Automatically created per region when you use networking features
// We explicitly create it here for the exercise
// ============================================================================
resource networkWatcher 'Microsoft.Network/networkWatchers@2023-09-01' = {
  name: 'nw-${location}'
  location: location
}

// ============================================================================
// LOG ANALYTICS WORKSPACE (for Traffic Analytics)
// ============================================================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-network-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ============================================================================
// STORAGE ACCOUNT (for NSG Flow Logs)
// ============================================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'stflow${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// ============================================================================
// VIRTUAL NETWORK & NSG
// ============================================================================
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-monitored'
  location: location
  properties: {
    securityRules: [
      { name: 'AllowSSH', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '22' } }
      { name: 'AllowHTTP', properties: { priority: 1100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '80' } }
      { name: 'DenyAll', properties: { priority: 4000, direction: 'Inbound', access: 'Deny', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*' } }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-monitored'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [{ name: 'snet-workload', properties: { addressPrefix: '10.0.1.0/24', networkSecurityGroup: { id: nsg.id } } }]
  }
}

// ============================================================================
// NSG FLOW LOGS
// Captures all traffic decisions made by the NSG
// ============================================================================
resource flowLog 'Microsoft.Network/networkWatchers/flowLogs@2023-09-01' = {
  parent: networkWatcher
  name: 'flowlog-nsg'
  location: location
  properties: {
    targetResourceId: nsg.id
    storageId: storageAccount.id
    enabled: true
    
    // Flow log version 2 includes bytes and packets
    format: { type: 'JSON', version: 2 }
    
    retentionPolicy: {
      enabled: true
      days: 7
    }
    
    // Traffic Analytics - provides insights from flow logs
    flowAnalyticsConfiguration: {
      networkWatcherFlowAnalyticsConfiguration: {
        enabled: true
        workspaceResourceId: logAnalytics.id
        trafficAnalyticsInterval: 10  // Minutes between analysis
      }
    }
  }
}

// ============================================================================
// TEST VM
// ============================================================================
resource pip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
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
        subnet: { id: '${vnet.id}/subnets/snet-workload' }
        publicIPAddress: { id: pip.id }
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-test'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-test', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'Canonical', offer: '0001-com-ubuntu-server-jammy', sku: '22_04-lts-gen2', version: 'latest' }
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}

// Network Watcher extension for packet capture
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vm
  name: 'NetworkWatcherAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
  }
}

output vmPublicIp string = pip.properties.ipAddress
output logAnalyticsWorkspace string = logAnalytics.name
output storageAccountForFlowLogs string = storageAccount.name

output ipFlowVerifyCommand string = 'az network watcher test-ip-flow --direction Inbound --protocol TCP --local 10.0.1.4:22 --remote 1.2.3.4:50000 --vm ${vm.name} -g ${resourceGroup().name}'
output nextHopCommand string = 'az network watcher show-next-hop --source-ip 10.0.1.4 --dest-ip 8.8.8.8 --vm ${vm.name} -g ${resourceGroup().name}'
