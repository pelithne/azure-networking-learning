// Module 13: Global Load Balancing
// This module creates both Traffic Manager and Front Door for comparison
param location string = resourceGroup().location
param uniqueSuffix string = uniqueString(resourceGroup().id)

// ============================================================================
// BACKEND WEB APPS (Origins for global load balancing)
// ============================================================================
resource appServicePlanEast 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-east'
  location: 'eastus'
  sku: { name: 'B1', tier: 'Basic' }
}

resource appServicePlanWest 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-west'
  location: 'westus'
  sku: { name: 'B1', tier: 'Basic' }
}

resource webAppEast 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-east-${uniqueSuffix}'
  location: 'eastus'
  properties: {
    serverFarmId: appServicePlanEast.id
    siteConfig: { appSettings: [{ name: 'REGION', value: 'East US' }] }
  }
}

resource webAppWest 'Microsoft.Web/sites@2023-01-01' = {
  name: 'app-west-${uniqueSuffix}'
  location: 'westus'
  properties: {
    serverFarmId: appServicePlanWest.id
    siteConfig: { appSettings: [{ name: 'REGION', value: 'West US' }] }
  }
}

// ============================================================================
// TRAFFIC MANAGER
// DNS-based global load balancing
// ============================================================================
resource trafficManager 'Microsoft.Network/trafficmanagerprofiles@2022-04-01' = {
  name: 'tm-global-${uniqueSuffix}'
  location: 'global'  // Traffic Manager is always global
  properties: {
    // ========================================================================
    // ROUTING METHOD
    // - Priority: Active/standby failover
    // - Weighted: Percentage distribution
    // - Performance: Lowest latency (most common)
    // - Geographic: Route by user location
    // ========================================================================
    trafficRoutingMethod: 'Performance'
    
    // DNS Settings
    dnsConfig: {
      relativeName: 'tm-global-${uniqueSuffix}'  // becomes <name>.trafficmanager.net
      ttl: 30  // Seconds. Lower = faster failover, more DNS queries
    }
    
    // Health monitoring
    monitorConfig: {
      protocol: 'HTTPS'
      port: 443
      path: '/'
      intervalInSeconds: 30
      timeoutInSeconds: 10
      toleratedNumberOfFailures: 3
    }
  }
}

// Traffic Manager Endpoints
resource tmEndpointEast 'Microsoft.Network/trafficmanagerprofiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'endpoint-east'
  properties: {
    targetResourceId: webAppEast.id
    endpointStatus: 'Enabled'
    priority: 1  // Used when routing = Priority
    weight: 50   // Used when routing = Weighted
  }
}

resource tmEndpointWest 'Microsoft.Network/trafficmanagerprofiles/azureEndpoints@2022-04-01' = {
  parent: trafficManager
  name: 'endpoint-west'
  properties: {
    targetResourceId: webAppWest.id
    endpointStatus: 'Enabled'
    priority: 2
    weight: 50
  }
}

// ============================================================================
// AZURE FRONT DOOR
// Application layer (L7) global load balancing with CDN
// ============================================================================
resource frontDoor 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: 'fd-global-${uniqueSuffix}'
  location: 'global'
  sku: { name: 'Standard_AzureFrontDoor' }
}

// Front Door Endpoint (the public-facing hostname)
resource fdEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoor
  name: 'ep-main'
  location: 'global'
  properties: { enabledState: 'Enabled' }
}

// Origin Group (backend pool)
resource fdOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoor
  name: 'og-webapps'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50  // Prefer origin within 50ms of best
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 30
    }
  }
}

// Origins (backends)
resource fdOriginEast 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: fdOriginGroup
  name: 'origin-east'
  properties: {
    hostName: webAppEast.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: webAppEast.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}

resource fdOriginWest 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: fdOriginGroup
  name: 'origin-west'
  properties: {
    hostName: webAppWest.properties.defaultHostName
    httpPort: 80
    httpsPort: 443
    originHostHeader: webAppWest.properties.defaultHostName
    priority: 1
    weight: 1000
  }
}

// Route (connects endpoint to origin group)
resource fdRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: fdEndpoint
  name: 'route-default'
  properties: {
    originGroup: { id: fdOriginGroup.id }
    supportedProtocols: ['Http', 'Https']
    patternsToMatch: ['/*']
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

output trafficManagerFqdn string = trafficManager.properties.dnsConfig.fqdn
output frontDoorFqdn string = fdEndpoint.properties.hostName
output webAppEastUrl string = 'https://${webAppEast.properties.defaultHostName}'
output webAppWestUrl string = 'https://${webAppWest.properties.defaultHostName}'
