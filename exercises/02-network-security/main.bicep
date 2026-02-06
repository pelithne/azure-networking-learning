// ============================================================================
// Module 2: Network Security - NSGs and ASGs
// ============================================================================
// This template deploys a 3-tier architecture with comprehensive network
// security using NSGs at subnet level and ASGs for logical grouping.
//
// NETWORKING CONCEPTS COVERED:
// - Network Security Groups (NSGs) and rule evaluation
// - Application Security Groups (ASGs) for role-based security
// - Service tags for simplified rule management
// - Defense-in-depth security model
// - Inbound vs outbound rule processing
// ============================================================================

// ----------------------------------------------------------------------------
// PARAMETERS
// ----------------------------------------------------------------------------

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Environment name for resource naming')
param environmentName string = 'learn'

@description('VM administrator username')
param adminUsername string = 'azureuser'

@description('VM administrator password')
@secure()
param adminPassword string

@description('Your public IP for SSH access (get from https://ifconfig.me)')
param allowedSshSourceIp string = '*'

// ----------------------------------------------------------------------------
// VARIABLES
// ----------------------------------------------------------------------------

var vnetName = 'vnet-${environmentName}-security'
var vnetAddressSpace = '10.1.0.0/16'

// Subnet definitions
var subnets = {
  web: {
    name: 'snet-web'
    addressPrefix: '10.1.1.0/24'
  }
  app: {
    name: 'snet-app'
    addressPrefix: '10.1.2.0/24'
  }
  db: {
    name: 'snet-db'
    addressPrefix: '10.1.3.0/24'
  }
}

// ============================================================================
// APPLICATION SECURITY GROUPS
// ============================================================================
// ASGs provide a way to group VMs by their role/function rather than by IP.
// This creates more maintainable and self-documenting security rules.
//
// KEY CONCEPTS:
// 1. ASGs are used WITHIN NSG rules as source or destination
// 2. VMs join ASGs via their NIC's ipConfiguration
// 3. One NIC can belong to multiple ASGs
// 4. ASGs must be in the same region as the resources using them
// 
// BENEFITS:
// - No need to update rules when VMs scale
// - Rules describe intent (allow webservers → appservers)
// - Easier security audits
// ============================================================================

@description('ASG for web tier servers')
resource asgWebServers 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = {
  name: 'asg-webservers'
  location: location
  tags: {
    tier: 'web'
    module: '02-network-security'
  }
  // ASGs have no properties - they're just logical containers
}

@description('ASG for application tier servers')
resource asgAppServers 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = {
  name: 'asg-appservers'
  location: location
  tags: {
    tier: 'app'
    module: '02-network-security'
  }
}

@description('ASG for database tier servers')
resource asgDbServers 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = {
  name: 'asg-dbservers'
  location: location
  tags: {
    tier: 'db'
    module: '02-network-security'
  }
}

// ============================================================================
// NETWORK SECURITY GROUPS
// ============================================================================
// NSGs contain security rules that allow or deny network traffic.
// Rules are evaluated by priority (lowest number = highest priority).
//
// RULE EVALUATION ORDER:
// 1. Lowest priority number is evaluated first
// 2. First matching rule (Allow or Deny) is applied
// 3. If no custom rule matches, default rules are evaluated
// 4. Default DenyAllInbound has priority 65500
//
// IMPORTANT NSG BEHAVIORS:
// - NSGs are stateful: return traffic is automatically allowed
// - You can have NSG on subnet AND NIC (both are evaluated)
// - Inbound: Subnet NSG → NIC NSG → VM
// - Outbound: VM → NIC NSG → Subnet NSG
// ============================================================================

// ----------------------------------------------------------------------------
// WEB TIER NSG
// ----------------------------------------------------------------------------
// This NSG protects the web tier - the entry point for external traffic.
// It allows HTTP/HTTPS from internet and SSH from specific IP.
// ----------------------------------------------------------------------------

@description('NSG for web subnet - allows HTTP/HTTPS from internet')
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-web'
  location: location
  tags: {
    tier: 'web'
    module: '02-network-security'
  }
  
  properties: {
    securityRules: [
      // ======================================================================
      // RULE: Allow HTTP from Internet
      // ======================================================================
      // This allows port 80 traffic from anywhere on the internet.
      //
      // SECURITY CONSIDERATION:
      // In production, you'd typically:
      // - Use HTTPS (443) instead
      // - Put Application Gateway or Azure Front Door in front
      // - Use WAF for additional protection
      // ======================================================================
      {
        name: 'AllowHTTPFromInternet'
        properties: {
          priority: 100  // Evaluated first among custom rules
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          
          // SOURCE: Where traffic originates
          // 'Internet' is a service tag = all public IPs not in Azure
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'  // Source port is typically ephemeral
          
          // DESTINATION: Where traffic is going
          destinationAddressPrefix: '*'  // Any IP in this subnet
          destinationPortRange: '80'
          
          description: 'Allow HTTP traffic from internet to web servers'
        }
      }
      
      // ======================================================================
      // RULE: Allow HTTPS from Internet
      // ======================================================================
      {
        name: 'AllowHTTPSFromInternet'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
          description: 'Allow HTTPS traffic from internet to web servers'
        }
      }
      
      // ======================================================================
      // RULE: Allow SSH from Specific IP
      // ======================================================================
      // SECURITY BEST PRACTICE:
      // - Never allow SSH from '*' (anywhere) in production
      // - Use Azure Bastion instead of direct SSH
      // - If SSH required, restrict to specific IPs
      // - Consider Just-in-Time VM access
      // ======================================================================
      {
        name: 'AllowSSHFromAdmin'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: allowedSshSourceIp  // Your IP only
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from admin IP only'
        }
      }
      
      // ======================================================================
      // RULE: Deny All Other Inbound
      // ======================================================================
      // EXPLICIT DENY: While there's a default DenyAllInbound at 65500,
      // adding an explicit deny rule:
      // 1. Documents your security intent
      // 2. Makes logs clearer (shows your rule, not default)
      // 3. Catches traffic before the default rule (if needed at lower priority)
      //
      // NOTE: This rule has priority 4096 (max custom priority).
      // Anything not matching rules 100-120 hits this deny.
      // ======================================================================
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicit deny for documentation and logging'
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// APP TIER NSG
// ----------------------------------------------------------------------------
// This NSG protects the application tier.
// It only allows traffic from the web tier on specific ports.
// ----------------------------------------------------------------------------

@description('NSG for app subnet - only allows traffic from web tier')
resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-app'
  location: location
  tags: {
    tier: 'app'
    module: '02-network-security'
  }
  
  properties: {
    securityRules: [
      // ======================================================================
      // RULE: Allow from Web ASG
      // ======================================================================
      // Using ASG as source instead of IP addresses.
      // This means: "Allow traffic from any VM in asg-webservers"
      //
      // IMPORTANT ASG RULE RESTRICTIONS:
      // 1. Cannot mix ASG with IP address prefix in same rule
      // 2. Cannot use ASG with service tags (except VirtualNetwork)
      // 3. Source/Destination ASGs must be in same VNet or peered VNets
      // ======================================================================
      {
        name: 'AllowFromWebTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          
          // SOURCE: Using ASG reference
          sourceApplicationSecurityGroups: [
            {
              id: asgWebServers.id
            }
          ]
          sourcePortRange: '*'
          
          // DESTINATION: Also using ASG
          destinationApplicationSecurityGroups: [
            {
              id: asgAppServers.id
            }
          ]
          // Allow multiple ports for app communication
          destinationPortRanges: [
            '8080'   // Application HTTP
            '8443'   // Application HTTPS
          ]
          
          description: 'Allow web servers to reach app servers'
        }
      }
      
      // ======================================================================
      // RULE: Allow SSH from Web Tier (for demo/troubleshooting)
      // ======================================================================
      // In production, you'd use Azure Bastion to the app tier
      // This rule demonstrates ASG-to-ASG communication
      // ======================================================================
      {
        name: 'AllowSSHFromWebTier'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            {
              id: asgWebServers.id
            }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgAppServers.id
            }
          ]
          destinationPortRange: '22'
          description: 'Allow SSH from web tier for troubleshooting'
        }
      }
      
      // ======================================================================
      // RULE: Deny Direct Internet Access
      // ======================================================================
      // The app tier should NEVER be directly accessible from internet.
      // This explicit rule blocks it with lowest priority (100 < this).
      //
      // WHY? The default rules allow VirtualNetwork traffic.
      // We want to ensure internet traffic is explicitly blocked.
      // ======================================================================
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicitly deny internet access to app tier'
        }
      }
      
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ----------------------------------------------------------------------------
// DATABASE TIER NSG  
// ----------------------------------------------------------------------------
// Most restrictive NSG - only allows SQL traffic from app tier.
// This represents a defense-in-depth approach where each tier
// can only communicate with its adjacent tier.
// ----------------------------------------------------------------------------

@description('NSG for database subnet - most restrictive, only SQL from app tier')
resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-db'
  location: location
  tags: {
    tier: 'db'
    module: '02-network-security'
  }
  
  properties: {
    securityRules: [
      // ======================================================================
      // RULE: Allow SQL from App Tier Only
      // ======================================================================
      // This rule implements the principle of least privilege:
      // - Only app servers can reach the database
      // - Only on the SQL port
      // - Web tier cannot directly access DB (must go through app tier)
      // ======================================================================
      {
        name: 'AllowSQLFromAppTier'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            {
              id: asgAppServers.id
            }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgDbServers.id
            }
          ]
          destinationPortRange: '1433'  // SQL Server default port
          description: 'Allow SQL traffic from app tier only'
        }
      }
      
      // ======================================================================
      // DENY RULES
      // ======================================================================
      // Multiple explicit deny rules for:
      // 1. Documentation and audit clarity
      // 2. Specific logging for blocked attempts
      // 3. Defense against misconfiguration
      // ======================================================================
      {
        name: 'DenyWebTierInbound'
        properties: {
          priority: 3000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceApplicationSecurityGroups: [
            {
              id: asgWebServers.id
            }
          ]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Explicitly deny web tier direct access to DB'
        }
      }
      
      {
        name: 'DenyInternetInbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all internet access to DB tier'
        }
      }
      
      {
        name: 'DenyAllOtherInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ============================================================================
// VIRTUAL NETWORK WITH SUBNETS
// ============================================================================

@description('Virtual Network with three tiers')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: {
    environment: environmentName
    module: '02-network-security'
  }
  
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressSpace]
    }
    
    // ========================================================================
    // SUBNETS WITH NSG ASSOCIATIONS
    // ========================================================================
    // NSGs can be attached at:
    // 1. Subnet level (affects all VMs in subnet)
    // 2. NIC level (affects specific VM)
    // 3. Both (both are evaluated, most restrictive wins)
    //
    // BEST PRACTICE:
    // - Use subnet-level NSGs for shared rules (tier-based access)
    // - Use NIC-level NSGs for exceptions (specific VM requirements)
    // ========================================================================
    subnets: [
      {
        name: subnets.web.name
        properties: {
          addressPrefix: subnets.web.addressPrefix
          // SUBNET-NSG ASSOCIATION
          // All VMs in this subnet are protected by this NSG
          networkSecurityGroup: {
            id: nsgWeb.id
          }
        }
      }
      {
        name: subnets.app.name
        properties: {
          addressPrefix: subnets.app.addressPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
      {
        name: subnets.db.name
        properties: {
          addressPrefix: subnets.db.addressPrefix
          networkSecurityGroup: {
            id: nsgDb.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP FOR WEB TIER
// ============================================================================

resource publicIpWeb 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-web-1'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// NETWORK INTERFACES WITH ASG MEMBERSHIP
// ============================================================================
// NICs are assigned to ASGs via the ipConfiguration property.
// This is how VMs become members of ASGs.
// ============================================================================

// Web tier NICs
resource nicWeb1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-web-1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIpWeb.id
          }
          // ================================================================
          // ASG MEMBERSHIP
          // ================================================================
          // This NIC is a member of asg-webservers.
          // NSG rules referencing this ASG will apply to this NIC.
          //
          // A NIC can belong to MULTIPLE ASGs:
          // applicationSecurityGroups: [
          //   { id: asg1.id }
          //   { id: asg2.id }
          // ]
          // ================================================================
          applicationSecurityGroups: [
            {
              id: asgWebServers.id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

resource nicWeb2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-web-2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[0].id
          }
          applicationSecurityGroups: [
            {
              id: asgWebServers.id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// App tier NICs
resource nicApp1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-app-1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[1].id
          }
          applicationSecurityGroups: [
            {
              id: asgAppServers.id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

resource nicApp2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-app-2'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[1].id
          }
          applicationSecurityGroups: [
            {
              id: asgAppServers.id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// DB tier NIC
resource nicDb 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-db'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork.properties.subnets[2].id
          }
          applicationSecurityGroups: [
            {
              id: asgDbServers.id
            }
          ]
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// ============================================================================
// VIRTUAL MACHINES
// ============================================================================
// VMs are created with custom script extension to install and run a simple
// web server, making it easy to test connectivity.
// ============================================================================

var vmConfig = {
  size: 'Standard_D2s_v3'
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
}

// Web VMs
resource vmWeb1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-web-1'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmConfig.size }
    osProfile: {
      computerName: 'vm-web-1'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmConfig.publisher
        offer: vmConfig.offer
        sku: vmConfig.sku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicWeb1.id }]
    }
  }
}

resource vmWeb2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-web-2'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmConfig.size }
    osProfile: {
      computerName: 'vm-web-2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmConfig.publisher
        offer: vmConfig.offer
        sku: vmConfig.sku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicWeb2.id }]
    }
  }
}

// App VMs
resource vmApp1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-app-1'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmConfig.size }
    osProfile: {
      computerName: 'vm-app-1'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmConfig.publisher
        offer: vmConfig.offer
        sku: vmConfig.sku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicApp1.id }]
    }
  }
}

resource vmApp2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-app-2'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmConfig.size }
    osProfile: {
      computerName: 'vm-app-2'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmConfig.publisher
        offer: vmConfig.offer
        sku: vmConfig.sku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicApp2.id }]
    }
  }
}

// DB VM
resource vmDb 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-db'
  location: location
  properties: {
    hardwareProfile: { vmSize: vmConfig.size }
    osProfile: {
      computerName: 'vm-db'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmConfig.publisher
        offer: vmConfig.offer
        sku: vmConfig.sku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: nicDb.id }]
    }
  }
}

// ============================================================================
// VM EXTENSIONS - Install simple web servers for testing
// ============================================================================

resource webServerExtWeb1 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vmWeb1
  name: 'installWebServer'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "Web Server 1 - $(hostname)" > /var/www/html/index.html'
    }
  }
}

resource webServerExtWeb2 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vmWeb2
  name: 'installWebServer'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y nginx && echo "Web Server 2 - $(hostname)" > /var/www/html/index.html'
    }
  }
}

resource webServerExtApp1 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vmApp1
  name: 'installAppServer'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      // Simple Python HTTP server on port 8080
      commandToExecute: 'apt-get update && apt-get install -y python3 && mkdir -p /app && echo "App Server 1" > /app/index.html && cd /app && nohup python3 -m http.server 8080 &'
    }
  }
}

resource webServerExtApp2 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: vmApp2
  name: 'installAppServer'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y python3 && mkdir -p /app && echo "App Server 2" > /app/index.html && cd /app && nohup python3 -m http.server 8080 &'
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('VNet resource ID')
output vnetId string = virtualNetwork.id

@description('Public IP for SSH access to web-1')
output webVmPublicIp string = publicIpWeb.properties.ipAddress

@description('SSH command')
output sshCommand string = 'ssh ${adminUsername}@${publicIpWeb.properties.ipAddress}'

@description('ASG IDs for reference')
output asgIds object = {
  webServers: asgWebServers.id
  appServers: asgAppServers.id
  dbServers: asgDbServers.id
}

@description('Private IPs for testing connectivity')
output privateIps object = {
  webVm1: nicWeb1.properties.ipConfigurations[0].properties.privateIPAddress
  webVm2: nicWeb2.properties.ipConfigurations[0].properties.privateIPAddress
  appVm1: nicApp1.properties.ipConfigurations[0].properties.privateIPAddress
  appVm2: nicApp2.properties.ipConfigurations[0].properties.privateIPAddress
  dbVm: nicDb.properties.ipConfigurations[0].properties.privateIPAddress
}

// ============================================================================
// NSG RULE SUMMARY FOR QUICK REFERENCE
// ============================================================================
// 
// WEB SUBNET (nsg-snet-web):
//   100: Allow HTTP (80) from Internet
//   110: Allow HTTPS (443) from Internet  
//   120: Allow SSH (22) from Admin IP
//   4096: Deny all other inbound
//
// APP SUBNET (nsg-snet-app):
//   100: Allow 8080,8443 from asg-webservers to asg-appservers
//   110: Allow SSH (22) from asg-webservers (for troubleshooting)
//   4000: Deny Internet inbound
//   4096: Deny all other inbound
//
// DB SUBNET (nsg-snet-db):
//   100: Allow SQL (1433) from asg-appservers to asg-dbservers
//   3000: Deny all from asg-webservers (explicit block)
//   4000: Deny Internet inbound
//   4096: Deny all other inbound
//
// TRAFFIC FLOW ALLOWED:
//   Internet → Web (HTTP/HTTPS) ✓
//   Web → App (8080/8443) ✓
//   App → DB (1433) ✓
//   Web → DB (any) ✗
//   Internet → App (any) ✗
//   Internet → DB (any) ✗
// ============================================================================
