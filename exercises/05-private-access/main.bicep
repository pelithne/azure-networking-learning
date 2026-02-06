// ============================================================================
// Module 5: Private Access - Private Endpoints
// ============================================================================
// This template deploys Private Endpoints for Azure Storage to demonstrate
// complete private connectivity to PaaS services.
//
// NETWORKING CONCEPTS COVERED:
// - Private Endpoints and Private Link
// - Private DNS Zones for name resolution
// - DNS Zone Groups for automatic DNS records
// - Disabling public access to PaaS services
// - groupId concept for service subresources
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

@description('Unique suffix for storage account name')
param storageNameSuffix string = uniqueString(resourceGroup().id)

// ----------------------------------------------------------------------------
// VARIABLES
// ----------------------------------------------------------------------------

var vnetName = 'vnet-private-access'
var vnetAddressSpace = '10.0.0.0/16'
var workloadSubnet = {
  name: 'snet-workload'
  prefix: '10.0.1.0/24'
}
var privateEndpointSubnet = {
  name: 'snet-privateendpoints'
  prefix: '10.0.2.0/24'
}

var storageAccountName = 'stlearn${storageNameSuffix}'

// ============================================================================
// PRIVATE DNS ZONE NAMING CONVENTION
// ============================================================================
// Azure Private Link uses specific DNS zone names for each service.
// The pattern is: privatelink.<service>.<domain>
//
// STORAGE DNS ZONES:
// - Blob:  privatelink.blob.core.windows.net
// - File:  privatelink.file.core.windows.net  
// - Queue: privatelink.queue.core.windows.net
// - Table: privatelink.table.core.windows.net
// - DFS:   privatelink.dfs.core.windows.net
// - Web:   privatelink.web.core.windows.net
//
// OTHER COMMON ZONES:
// - SQL:       privatelink.database.windows.net
// - Key Vault: privatelink.vaultcore.azure.net
// - ACR:       privatelink.azurecr.io
// - Event Hub: privatelink.servicebus.windows.net
// ============================================================================
var privateDnsZoneName = 'privatelink.blob.core.windows.net'

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
      {
        name: workloadSubnet.name
        properties: {
          addressPrefix: workloadSubnet.prefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: privateEndpointSubnet.name
        properties: {
          addressPrefix: privateEndpointSubnet.prefix
          
          // ================================================================
          // PRIVATE ENDPOINT NETWORK POLICIES
          // ================================================================
          // By default, NSG rules and UDRs do NOT apply to private endpoints.
          // This is because private endpoints use a special network flow.
          //
          // Settings:
          // - 'Disabled' (default): NSG/UDR don't affect private endpoints
          // - 'Enabled': Apply NSG/UDR to private endpoint traffic
          //
          // WHY DISABLED BY DEFAULT?
          // - Private endpoints need to receive traffic from the PaaS service
          // - NSG might accidentally block this traffic
          // - Simpler initial configuration
          //
          // WHEN TO ENABLE?
          // - Need to log/audit private endpoint traffic with NSG flow logs
          // - Need to route private endpoint traffic through NVA
          // - Compliance requires explicit security rules
          // ================================================================
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ============================================================================
// STORAGE ACCOUNT
// ============================================================================
// Target PaaS service for private endpoint demonstration.
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // ========================================================================
    // PUBLIC NETWORK ACCESS
    // ========================================================================
    // This is the KEY setting for private endpoint security.
    //
    // Options:
    // - 'Enabled': Allow public internet access (default)
    // - 'Disabled': Block ALL public access, only private endpoints work
    //
    // SECURITY RECOMMENDATION:
    // For sensitive data, ALWAYS set to 'Disabled' when using private endpoints.
    // This ensures data ONLY flows through your VNet.
    //
    // We disable it here to demonstrate full private connectivity.
    // ========================================================================
    publicNetworkAccess: 'Disabled'
    
    // Allow shared key access for testing
    allowSharedKeyAccess: true
    
    // TLS version
    minimumTlsVersion: 'TLS1_2'
    
    // Secure transfer required
    supportsHttpsTrafficOnly: true
    
    // Network rules (additional layer even with private endpoints)
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
  }
}

// Create a container for testing
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'test'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// PRIVATE DNS ZONE
// ============================================================================
// Private DNS Zones provide name resolution for private endpoints.
// This is CRITICAL - without proper DNS, clients will resolve public IPs!
// ============================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'  // Private DNS zones are global resources
  
  tags: {
    purpose: 'private-endpoint-dns'
    service: 'blob-storage'
  }
}

// ============================================================================
// PRIVATE DNS ZONE VNET LINK
// ============================================================================
// Links the private DNS zone to a VNet so VMs in that VNet can resolve
// the private endpoint FQDNs.
// ============================================================================

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'link-${vnetName}'
  location: 'global'
  
  properties: {
    // The VNet where DNS resolution should work
    virtualNetwork: {
      id: vnet.id
    }
    
    // ========================================================================
    // REGISTRATION ENABLED
    // ========================================================================
    // When true, VMs in this VNet automatically register their names
    // in this DNS zone. Not needed for private endpoints (they use DNS groups)
    // but useful for VM name resolution.
    //
    // For private endpoint zones, typically set to false.
    // ========================================================================
    registrationEnabled: false
  }
}

// ============================================================================
// PRIVATE ENDPOINT
// ============================================================================
// The private endpoint creates a network interface in your VNet that
// connects to the PaaS service through Azure Private Link.
// ============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-storage-blob'
  location: location
  
  properties: {
    // Subnet where the private endpoint NIC will be created
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnet.name}'
    }
    
    // ========================================================================
    // PRIVATE LINK SERVICE CONNECTIONS
    // ========================================================================
    // Defines which PaaS service to connect to and which subresource.
    // ========================================================================
    privateLinkServiceConnections: [
      {
        name: 'plsc-storage-blob'
        properties: {
          // The PaaS resource to connect to
          privateLinkServiceId: storageAccount.id
          
          // ================================================================
          // GROUP IDS (Subresources)
          // ================================================================
          // Many PaaS services have multiple subresources.
          // You need a separate private endpoint for each subresource.
          //
          // STORAGE GROUP IDS:
          // - blob: Blob storage (most common)
          // - blob_secondary: Read-access geo-redundant blob
          // - file: File shares
          // - queue: Queue storage
          // - table: Table storage
          // - web: Static website
          // - dfs: Data Lake (ADLS Gen2)
          //
          // SQL GROUP IDS:
          // - sqlServer: SQL Database
          //
          // KEY VAULT GROUP IDS:
          // - vault: Key Vault secrets, keys, certs
          //
          // You must create SEPARATE private endpoints for each subresource
          // you want to access privately!
          // ================================================================
          groupIds: [
            'blob'
          ]
          
          // Request message for approval (auto-approved for same tenant)
          requestMessage: 'Private endpoint for storage blob access'
        }
      }
    ]
    
    // ========================================================================
    // CUSTOM DNS CONFIGS (Read-only after creation)
    // ========================================================================
    // After creation, this will contain:
    // - FQDN: <storageaccount>.blob.core.windows.net
    // - IP Addresses: [10.0.2.4] (the private IP)
    //
    // This information is used to create DNS records.
    // ========================================================================
    
    // Optional: Static IP assignment (usually let Azure assign dynamically)
    // ipConfigurations: [
    //   {
    //     name: 'ipconfig1'
    //     properties: {
    //       groupId: 'blob'
    //       memberName: 'blob'
    //       privateIPAddress: '10.0.2.10'  // Specific IP
    //     }
    //   }
    // ]
  }
}

// ============================================================================
// PRIVATE DNS ZONE GROUP
// ============================================================================
// This automatically creates DNS records in the private DNS zone
// for the private endpoint. Without this, you'd need to manually create
// A records for each private endpoint.
// ============================================================================

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'default'
  
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          // Link to the private DNS zone where records should be created
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP FOR VM
// ============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-client'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// NETWORK INTERFACE
// ============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-client'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${workloadSubnet.name}'
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// VIRTUAL MACHINE
// ============================================================================

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-client'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'vm-client'
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

@description('VM public IP for SSH access')
output vmPublicIp string = publicIp.properties.ipAddress

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Storage endpoint (try nslookup from VM)')
output storageEndpoint string = '${storageAccount.name}.blob.core.windows.net'

@description('Private endpoint private IP')
output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]

@description('SSH command')
output sshCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'

@description('Test commands to run from VM')
output testCommands object = {
  dnsLookup: 'nslookup ${storageAccount.name}.blob.core.windows.net'
  testConnectivity: 'curl -I https://${storageAccount.name}.blob.core.windows.net/'
  expectedDnsResult: 'Should resolve to ${privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]}'
}

// ============================================================================
// DNS RESOLUTION FLOW
// ============================================================================
//
// FROM VM IN VNET (with Private DNS Zone Link):
//
// 1. VM queries: mystore.blob.core.windows.net
//    └─► Azure DNS (168.63.129.16)
//
// 2. Azure DNS returns CNAME:
//    mystore.blob.core.windows.net → mystore.privatelink.blob.core.windows.net
//
// 3. VM queries: mystore.privatelink.blob.core.windows.net
//    └─► Azure DNS checks private DNS zones linked to VNet
//
// 4. Private DNS Zone has A record:
//    mystore.privatelink.blob.core.windows.net → 10.0.2.4
//
// 5. VM connects to 10.0.2.4 (private endpoint NIC)
//    └─► Traffic stays entirely in VNet!
//
// FROM EXTERNAL CLIENT (no Private DNS):
//
// 1. Client queries: mystore.blob.core.windows.net
//    └─► Public DNS
//
// 2. Returns CNAME → mystore.privatelink.blob.core.windows.net
//
// 3. Public DNS resolves to public IP (blocked!)
//    OR times out if public access fully disabled
//
// ============================================================================
