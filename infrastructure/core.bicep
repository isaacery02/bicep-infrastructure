/******************
* Core Bicep File
******************/

/******************
* Parameters
******************/
@description('Location of the deployment')
@allowed([
  'uksouth'
  'northeurope'
])
param parlocation string = 'uksouth'
param parprefix string = 'uks'
param parVNETName string = 'hub'
@description('CIDR Ranges for the vnet')
param parhubvnetSettings object = {
    addressPrefix : [
        '10.0.0.0/16'
    ]
    subnets : [
        {
        name: 'subnetProdHub'
        addressPrefix: '10.0.1.0/24'
        }
        {
        name: 'subnetIntegHub'
        addressPrefix: '10.0.2.0/24'
        }
        {
        name: 'subACAControl'
        addressPrefix: '10.0.4.0/23'
        }
        {
        name: 'subACAApps'
        addressPrefix: '10.0.6.0/23'
        }
    ]
}

/******************
* Variables
******************/
var location = toLower(parlocation)
var varSupportedLocations = {
    northeurope: {
      suffix: 'neu'
    }
    uksouth: {
      suffix: 'uks'
    }
  }
  
var varLocationSuffix = varSupportedLocations[location].suffix
var varEnvironment = 'Prod'
var varTags = {
  Environment: varEnvironment
  Location: parprefix
}
var varHubVnetName = 'vnet-${parVNETName}-${varLocationSuffix}'
var varHubNSGName = 'nsg-${parVNETName}-${varLocationSuffix}'

/******************
* Resources
******************/

resource resSubnetNSG 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
    name: varHubNSGName
  location: location
  properties: {
    securityRules: [
    ]
  }
  tags: varTags
}


resource resHubvirtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: varHubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: parhubvnetSettings.addressPrefix
    }
    subnets: [ for subnet in parhubvnetSettings.subnets: {
        name: subnet.name
        properties : {
            addressPrefix: subnet.addressPrefix
            networkSecurityGroup: {id: resSubnetNSG.id}
            privateEndpointNetworkPolicies:'Enabled'
            serviceEndpoints: [
              {
                service: 'Microsoft.KeyVault'
                locations: [
                  '*'
                ]
              }
            ]
          }
        }
    ]
  }
}

resource resGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-03-01' = {
    parent: resHubvirtualNetwork
    name: 'GatewaySubnet'
    properties:       {
        addressPrefix: '10.0.3.0/24'
        privateEndpointNetworkPolicies:'Enabled'
        serviceEndpoints: [
          {
            service: 'Microsoft.KeyVault'
            locations: [
              '*'
            ]
          }
        ]
      }
}

resource resCosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: 'cos-hub-prod-${varLocationSuffix}'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource resSqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: resCosmosDbAccount
    name: 'sqldb-cos-prod-${varLocationSuffix}'
  properties: {
    resource: {
      id: 'sqldb-cos-prod-${varLocationSuffix}'
    }
    options: {
    }
  }
}

resource sqlContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: resSqlDb 
  name: 'orders-prod-${varLocationSuffix}'
  properties: {
    resource: {
      id: 'orders-prod-${varLocationSuffix}'
      partitionKey: {
        paths: [
          '/id'
        ]
      }
    }
    options: {}
  }
}

resource resPrivateDNSZone  'microsoft.network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
}

// Link the Private DNS Zone to the VNet
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
    parent: resPrivateDNSZone
    name: 'cosmos-dns-link-${varLocationSuffix}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: resHubvirtualNetwork.id
      }
    }
  }

//Create the Private endpoint
// Private Endpoint for the Storage Account, using the main subnet
resource resCosmosprivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
    name: 'pe-${resCosmosDbAccount.name}'
    location: location
    properties: {
      subnet: {
        id: resHubvirtualNetwork.properties.subnets[1].id
      }
      privateLinkServiceConnections: [
        {
          name: 'pe-connection-cosmos}'
          properties: {
            privateLinkServiceId: resCosmosDbAccount.id
            groupIds: ['SQL']
          }
        }
      ]
    }
  }


// DNS Zone Group for the Private Endpoint
// This automatically creates the necessary DNS records in the Private DNS Zone
resource resCosPEDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
    parent: resCosmosprivateEndpoint
    name: 'pe-dnsgroup-cosmos-${varLocationSuffix}'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.documents.azure.com'
          properties: {
            privateDnsZoneId: resPrivateDNSZone.id
          }
        }
      ]
    }
  }

//Create the KeyVault





