// ============================================================================
// Module 6: Azure Load Balancer
// ============================================================================
// This template deploys both Public and Internal Load Balancers to
// demonstrate L4 load balancing concepts.
//
// NETWORKING CONCEPTS COVERED:
// - Public vs Internal Load Balancer
// - Frontend IP configurations
// - Backend pools and health probes
// - Load balancing rules and distribution
// - SNAT and outbound rules
// - Inbound NAT rules for direct VM access
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

var vnetName = 'vnet-loadbalancer'
var vnetAddressSpace = '10.0.0.0/16'

var subnets = {
  web: {
    name: 'snet-web'
    prefix: '10.0.1.0/24'
  }
  app: {
    name: 'snet-app'
    prefix: '10.0.2.0/24'
  }
}

var webVmCount = 3
var appVmCount = 2

// ============================================================================
// NETWORK SECURITY GROUP
// ============================================================================
// NSG rules are CRITICAL for Standard Load Balancer!
// Standard LB is "secure by default" - denies all traffic unless allowed.
// ============================================================================

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-web'
  location: location
  properties: {
    securityRules: [
      // ======================================================================
      // ALLOW HTTP FROM INTERNET
      // ======================================================================
      // CRITICAL: Standard LB requires explicit NSG rules!
      // Without this, health probes and client traffic will be blocked.
      // ======================================================================
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      // ======================================================================
      // ALLOW HEALTH PROBES FROM LOAD BALANCER
      // ======================================================================
      // The AzureLoadBalancer service tag represents the source IP of
      // Azure's health probe infrastructure.
      //
      // Without this rule, health probes will fail and all backends
      // will be marked unhealthy!
      // ======================================================================
      {
        name: 'AllowLoadBalancerProbe'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Allow health probes from Azure Load Balancer'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowFromWebTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.web.prefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'AllowLoadBalancerProbe'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowSSHFromWeb'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnets.web.prefix
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
        name: subnets.web.name
        properties: {
          addressPrefix: subnets.web.prefix
          networkSecurityGroup: { id: nsgWeb.id }
        }
      }
      {
        name: subnets.app.name
        properties: {
          addressPrefix: subnets.app.prefix
          networkSecurityGroup: { id: nsgApp.id }
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP FOR PUBLIC LOAD BALANCER
// ============================================================================

resource publicIpLb 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-lb-public'
  location: location
  
  // Standard SKU is required for Standard Load Balancer
  sku: {
    name: 'Standard'
  }
  
  // Zone-redundant for high availability
  zones: ['1', '2', '3']
  
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// PUBLIC LOAD BALANCER
// ============================================================================
// Distributes incoming internet traffic across backend VMs.
// ============================================================================

resource publicLoadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: 'lb-public'
  location: location
  
  // ========================================================================
  // LOAD BALANCER SKU
  // ========================================================================
  // Standard SKU provides:
  // - SLA of 99.99%
  // - Zone redundancy
  // - Secure by default (requires NSG)
  // - Outbound rules support
  // - Larger backend pools
  //
  // ALWAYS use Standard for production!
  // ========================================================================
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  
  properties: {
    // ======================================================================
    // FRONTEND IP CONFIGURATION
    // ======================================================================
    // The IP address(es) that receive incoming traffic.
    // Can have multiple frontends for different services.
    // ======================================================================
    frontendIPConfigurations: [
      {
        name: 'frontend-public'
        properties: {
          publicIPAddress: {
            id: publicIpLb.id
          }
        }
        // Zone-redundant when public IP is zone-redundant
        zones: ['1', '2', '3']
      }
    ]
    
    // ======================================================================
    // BACKEND ADDRESS POOL
    // ======================================================================
    // The collection of resources that receive distributed traffic.
    // VMs are added via their NIC's IP configuration.
    //
    // BACKEND POOL TYPES:
    // - NIC-based: Traditional, VMs join via NIC association
    // - IP-based: Newer, can include external IPs or IP ranges
    // ======================================================================
    backendAddressPools: [
      {
        name: 'backend-web'
      }
    ]
    
    // ======================================================================
    // HEALTH PROBES
    // ======================================================================
    // Determines which backend instances are healthy.
    // Unhealthy instances are removed from rotation.
    //
    // PROBE TYPES:
    // - TCP: Just checks if port is open
    // - HTTP: Sends GET request, expects 200 OK
    // - HTTPS: Same as HTTP but with TLS
    //
    // HTTP/HTTPS is recommended - more accurate health check
    // ======================================================================
    probes: [
      {
        name: 'probe-http'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'  // Path to check
          
          // ================================================================
          // PROBE CONFIGURATION
          // ================================================================
          // intervalInSeconds: Time between probes
          // - Lower = faster detection, more probe traffic
          // - Higher = slower detection, less overhead
          //
          // numberOfProbes (unhealthyThreshold): Failed probes before unhealthy
          // - Set > 1 to avoid false positives from transient issues
          // ================================================================
          intervalInSeconds: 5
          numberOfProbes: 2  // 2 failures (10 seconds) to mark unhealthy
        }
      }
    ]
    
    // ======================================================================
    // LOAD BALANCING RULES
    // ======================================================================
    // Maps frontend IP:port to backend pool:port
    // ======================================================================
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          // Frontend to receive traffic
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-public', 'frontend-public')
          }
          
          // Backend to distribute to
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-public', 'backend-web')
          }
          
          // Health check to use
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-public', 'probe-http')
          }
          
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          
          // ================================================================
          // LOAD DISTRIBUTION
          // ================================================================
          // 'Default' = 5-tuple hash (source/dest IP, source/dest port, protocol)
          // 'SourceIP' = 2-tuple (source IP, dest IP) - Client affinity
          // 'SourceIPProtocol' = 3-tuple (source IP, dest IP, protocol)
          //
          // Use 'SourceIP' when you need session persistence (sticky sessions)
          // ================================================================
          loadDistribution: 'Default'
          
          // ================================================================
          // IDLE TIMEOUT
          // ================================================================
          // How long to keep connection open with no traffic.
          // Range: 4-30 minutes
          // 
          // Higher values reduce reconnection overhead but use more resources.
          // For HTTP, typically keep low (4 mins).
          // For long-running connections, increase as needed.
          // ================================================================
          idleTimeoutInMinutes: 4
          
          // ================================================================
          // ENABLE TCP RESET
          // ================================================================
          // Sends TCP RST to both directions when connection times out.
          // Helps applications detect dead connections faster.
          // Recommended: true
          // ================================================================
          enableTcpReset: true
          
          // ================================================================
          // DISABLE OUTBOUND SNAT
          // ================================================================
          // When true, this rule doesn't provide outbound SNAT.
          // Use with outbound rules for explicit outbound config.
          //
          // Set to true when:
          // - You want explicit outbound rules
          // - Using NAT Gateway for outbound
          // ================================================================
          disableOutboundSnat: true
        }
      }
    ]
    
    // ======================================================================
    // OUTBOUND RULES
    // ======================================================================
    // Explicit SNAT configuration for outbound connections.
    // Required when disableOutboundSnat is true on LB rules.
    // ======================================================================
    outboundRules: [
      {
        name: 'outbound-web'
        properties: {
          frontendIPConfigurations: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-public', 'frontend-public')
            }
          ]
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-public', 'backend-web')
          }
          protocol: 'All'
          
          // ================================================================
          // SNAT PORT ALLOCATION
          // ================================================================
          // Azure allocates SNAT ports per backend instance.
          //
          // enableTcpReset: RST on connection timeout
          // idleTimeoutInMinutes: Timeout for outbound connections
          // allocatedOutboundPorts: Ports per instance (manual allocation)
          //
          // If not specified, Azure auto-allocates based on pool size.
          // ================================================================
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          // allocatedOutboundPorts: 10000  // Manual allocation
        }
      }
    ]
    
    // ======================================================================
    // INBOUND NAT RULES
    // ======================================================================
    // Maps specific frontend port to specific backend VM.
    // Useful for SSH/RDP to individual backend VMs.
    //
    // Example: Frontend port 50001 → VM1:22
    //          Frontend port 50002 → VM2:22
    // ======================================================================
    inboundNatRules: [
      {
        name: 'ssh-vm1'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-public', 'frontend-public')
          }
          protocol: 'Tcp'
          frontendPort: 50001
          backendPort: 22
          enableTcpReset: true
          idleTimeoutInMinutes: 4
        }
      }
      {
        name: 'ssh-vm2'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-public', 'frontend-public')
          }
          protocol: 'Tcp'
          frontendPort: 50002
          backendPort: 22
          enableTcpReset: true
          idleTimeoutInMinutes: 4
        }
      }
      {
        name: 'ssh-vm3'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-public', 'frontend-public')
          }
          protocol: 'Tcp'
          frontendPort: 50003
          backendPort: 22
          enableTcpReset: true
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

// ============================================================================
// INTERNAL LOAD BALANCER
// ============================================================================
// Distributes traffic within the VNet (no public exposure).
// Used for internal tiers (app servers, databases, etc.)
// ============================================================================

resource internalLoadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: 'lb-internal'
  location: location
  
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend-internal'
        properties: {
          // ================================================================
          // INTERNAL FRONTEND CONFIGURATION
          // ================================================================
          // For internal LB, specify a subnet and private IP.
          //
          // privateIPAllocationMethod:
          // - 'Dynamic': Azure assigns next available IP
          // - 'Static': You specify the IP (must be in subnet range)
          //
          // Static is recommended for:
          // - Known/stable IP for DNS
          // - Easier troubleshooting
          // ================================================================
          subnet: {
            id: '${vnet.id}/subnets/${subnets.app.name}'
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.2.100'
        }
        // Can specify zones for zonal or zone-redundant
        zones: ['1', '2', '3']
      }
    ]
    
    backendAddressPools: [
      {
        name: 'backend-app'
      }
    ]
    
    probes: [
      {
        name: 'probe-app'
        properties: {
          protocol: 'Tcp'
          port: 8080
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    
    loadBalancingRules: [
      {
        name: 'app-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-internal', 'frontend-internal')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-internal', 'backend-app')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-internal', 'probe-app')
          }
          protocol: 'Tcp'
          frontendPort: 8080
          backendPort: 8080
          loadDistribution: 'Default'
          enableTcpReset: true
          idleTimeoutInMinutes: 4
          
          // Internal LB typically doesn't need outbound rules
          disableOutboundSnat: false
        }
      }
    ]
  }
}

// ============================================================================
// WEB TIER VMs (Behind Public LB)
// ============================================================================

resource nicWeb 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, webVmCount): {
  name: 'nic-vm-web-${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnets.web.name}'
          }
          
          // ================================================================
          // BACKEND POOL ASSOCIATION
          // ================================================================
          // This is how a NIC joins a load balancer backend pool.
          // The VM will receive load-balanced traffic.
          // ================================================================
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-public', 'backend-web')
            }
          ]
          
          // ================================================================
          // INBOUND NAT RULE ASSOCIATION
          // ================================================================
          // Associates this NIC with a specific NAT rule for direct access.
          // ================================================================
          loadBalancerInboundNatRules: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/inboundNatRules', 'lb-public', 'ssh-vm${i + 1}')
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
  dependsOn: [publicLoadBalancer]
}]

resource vmWeb 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, webVmCount): {
  name: 'vm-web-${i + 1}'
  location: location
  zones: [string((i % 3) + 1)]  // Distribute across zones
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v3' }
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
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicWeb[i].id }]
    }
  }
}]

// Install nginx on web VMs
resource webServerExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, webVmCount): {
  parent: vmWeb[i]
  name: 'installNginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "Hello from vm-web-${i + 1}" > /var/www/html/index.html && systemctl enable nginx'
    }
  }
}]

// ============================================================================
// APP TIER VMs (Behind Internal LB)
// ============================================================================

resource nicApp 'Microsoft.Network/networkInterfaces@2023-09-01' = [for i in range(0, appVmCount): {
  name: 'nic-vm-app-${i + 1}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnets.app.name}'
          }
          loadBalancerBackendAddressPools: [
            {
              id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-internal', 'backend-app')
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
  dependsOn: [internalLoadBalancer]
}]

resource vmApp 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, appVmCount): {
  name: 'vm-app-${i + 1}'
  location: location
  zones: [string((i % 3) + 1)]
  properties: {
    hardwareProfile: { vmSize: 'Standard_D2s_v3' }
    osProfile: {
      computerName: 'vm-app-${i + 1}'
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
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicApp[i].id }]
    }
  }
}]

// Install simple python http server on app VMs
resource appServerExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, appVmCount): {
  parent: vmApp[i]
  name: 'installApp'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y python3 && mkdir -p /app && echo "Response from vm-app-${i + 1}" > /app/index.html && cd /app && nohup python3 -m http.server 8080 &'
    }
  }
}]

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Public LB IP address')
output publicLbIp string = publicIpLb.properties.ipAddress

@description('Internal LB IP address')
output internalLbIp string = internalLoadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress

@description('SSH commands for each web VM')
output sshCommands array = [for i in range(0, webVmCount): 'ssh -p ${50001 + i} ${adminUsername}@${publicIpLb.properties.ipAddress}']

@description('Test commands')
output testCommands object = {
  testPublicLb: 'for i in {1..10}; do curl -s http://${publicIpLb.properties.ipAddress}; done'
  testInternalLb: 'curl http://${internalLoadBalancer.properties.frontendIPConfigurations[0].properties.privateIPAddress}:8080'
}

// ============================================================================
// LOAD BALANCING TRAFFIC FLOW
// ============================================================================
//
// PUBLIC LOAD BALANCER INBOUND:
//
//  Client (Internet)
//       │
//       │ HTTP :80
//       ▼
//  ┌─────────────────┐
//  │   Public IP     │  20.x.x.x:80
//  └────────┬────────┘
//           │
//  ┌────────┴────────┐
//  │    Frontend     │  Receives traffic
//  └────────┬────────┘
//           │
//  ┌────────┴────────┐
//  │  LB Rule (80)   │  Matches protocol/port
//  └────────┬────────┘
//           │
//  ┌────────┴────────┐
//  │  Health Probe   │  Filters unhealthy VMs
//  └────────┬────────┘
//           │
//  ┌────────┴────────┐
//  │  5-tuple Hash   │  Selects backend VM
//  └────────┬────────┘
//           │
//      ┌────┴────┬────────┐
//      ▼         ▼        ▼
//   vm-web-1  vm-web-2  vm-web-3
//
// ============================================================================
