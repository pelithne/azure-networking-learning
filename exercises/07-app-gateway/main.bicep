// ============================================================================
// Module 7: Application Gateway
// ============================================================================
// Layer 7 load balancer with SSL termination, URL routing, and WAF.
// ============================================================================

param location string = resourceGroup().location
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

var vnetName = 'vnet-appgw'
var appGwSubnetPrefix = '10.0.0.0/24'  // Dedicated subnet for App Gateway
var backendSubnetPrefix = '10.0.1.0/24'

// ============================================================================
// NSG for Backend Subnet
// ============================================================================
resource nsgBackend 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-backend'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAppGateway'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appGwSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
          description: 'Required for App Gateway v2 management'
        }
      }
    ]
  }
}

// ============================================================================
// NSG for Application Gateway Subnet
// ============================================================================
// Application Gateway v2 requires specific NSG rules
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-appgw'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      // ======================================================================
      // CRITICAL: Gateway Manager Access
      // ======================================================================
      // App Gateway v2 REQUIRES this rule for Azure to manage the gateway.
      // Without it, the gateway will show unhealthy status.
      // ======================================================================
      {
        name: 'AllowGatewayManager'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
          description: 'Allow Azure to manage App Gateway'
        }
      }
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// VNet
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [
      {
        // ====================================================================
        // APPLICATION GATEWAY SUBNET
        // ====================================================================
        // Dedicated subnet for App Gateway.
        // - Can have any name (not a special name like GatewaySubnet)
        // - Minimum recommended: /24 (App Gateway scales within subnet)
        // - Cannot contain other resources
        // ====================================================================
        name: 'snet-appgw'
        properties: {
          addressPrefix: appGwSubnetPrefix
          networkSecurityGroup: { id: nsgAppGw.id }
        }
      }
      {
        name: 'snet-backend'
        properties: {
          addressPrefix: backendSubnetPrefix
          networkSecurityGroup: { id: nsgBackend.id }
        }
      }
    ]
  }
}

// Public IP for App Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-appgw'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// ============================================================================
// APPLICATION GATEWAY
// ============================================================================
resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: 'appgw-main'
  location: location
  properties: {
    // ========================================================================
    // SKU
    // ========================================================================
    // Standard_v2: Basic L7 load balancing
    // WAF_v2: Includes Web Application Firewall
    // ========================================================================
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    
    // Autoscaling (v2 only)
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 3
    }
    
    // ========================================================================
    // GATEWAY IP CONFIGURATION
    // ========================================================================
    // Connects App Gateway to the subnet
    // ========================================================================
    gatewayIPConfigurations: [
      {
        name: 'appGwIpConfig'
        properties: {
          subnet: { id: '${vnet.id}/subnets/snet-appgw' }
        }
      }
    ]
    
    // ========================================================================
    // FRONTEND IP CONFIGURATION
    // ========================================================================
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontend'
        properties: {
          publicIPAddress: { id: publicIp.id }
        }
      }
    ]
    
    // ========================================================================
    // FRONTEND PORTS
    // ========================================================================
    frontendPorts: [
      { name: 'port_80', properties: { port: 80 } }
    ]
    
    // ========================================================================
    // BACKEND ADDRESS POOLS
    // ========================================================================
    // Can contain: VMs, VMSS, App Services, IPs, FQDNs
    // ========================================================================
    backendAddressPools: [
      {
        name: 'backend-web'
        properties: {
          backendAddresses: [
            { ipAddress: '10.0.1.4' }
            { ipAddress: '10.0.1.5' }
          ]
        }
      }
    ]
    
    // ========================================================================
    // BACKEND HTTP SETTINGS
    // ========================================================================
    // Defines protocol, port, and behavior for backend connections
    // ========================================================================
    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          
          // Custom probe
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', 'appgw-main', 'health-probe') }
        }
      }
    ]
    
    // ========================================================================
    // HEALTH PROBES
    // ========================================================================
    // HTTP-aware health checks (can check specific paths, status codes)
    // ========================================================================
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Http'
          host: '127.0.0.1'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          match: {
            statusCodes: ['200-399']
          }
        }
      }
    ]
    
    // ========================================================================
    // HTTP LISTENERS
    // ========================================================================
    // Listen for incoming requests
    // ========================================================================
    httpListeners: [
      {
        name: 'listener-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'appgw-main', 'appGwPublicFrontend')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'appgw-main', 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    
    // ========================================================================
    // REQUEST ROUTING RULES
    // ========================================================================
    // Connect listeners to backend pools
    // ========================================================================
    requestRoutingRules: [
      {
        name: 'rule-basic'
        properties: {
          priority: 100
          ruleType: 'Basic'  // or 'PathBasedRouting'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'appgw-main', 'listener-http')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'appgw-main', 'backend-web')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'appgw-main', 'http-settings')
          }
        }
      }
    ]
  }
}

// Backend VMs
resource nicVm 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, 2): {
  name: 'nic-vm-web-${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.${4 + i}'
          subnet: { id: '${vnet.id}/subnets/snet-backend' }
        }
      }
    ]
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, 2): {
  name: 'vm-web-${i + 1}'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'vm-web-${i + 1}'
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
      osDisk: { createOption: 'FromImage' }
    }
    networkProfile: { networkInterfaces: [{ id: nicVm[i].id }] }
  }
}]

resource vmExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, 2): {
  parent: vm[i]
  name: 'installNginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "Backend: vm-web-${i + 1}" > /var/www/html/index.html'
    }
  }
}]

output appGatewayPublicIp string = publicIp.properties.ipAddress
output testCommand string = 'curl http://${publicIp.properties.ipAddress}'
