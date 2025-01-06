/*************
* Purpose of this file
* 
*************/

/*******************
* Parameters
*******************/
@description('Location of the deployment')
param parlocation string = 'uksouth'
@allowed([
  'uks'
  'ne'
])
param parprefix string = 'uks'
param parEnvironment string = 'Prod'
param parLocationSuffix string = 'uks'
param parHubVnet string

/*******************
* Variables
*******************/
var varTags = {
  Environment: parEnvironment
  Location: parprefix
}

/*******************
* References
*******************/
resource refHubvirtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: parHubVnet
}

/*
resource refPESubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  name: 'subnetProdHub'
  parent: refHubvirtualNetwork
}
*/

/*******************
* Modules
*******************/
resource resCosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2021-03-15' = {
  name: 'cos-hub-prod-${parLocationSuffix}'
  location: parlocation
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: parlocation
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
  tags: varTags
}

resource resSqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-06-15' = {
  parent: resCosmosDbAccount
    name: 'sqldb-cos-prod-${parLocationSuffix}'
  properties: {
    resource: {
      id: 'sqldb-cos-prod-${parLocationSuffix}'
    }
    options: {
    }
  }
}

resource resSqlContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
  parent: resSqlDb 
  name: 'orders-prod-${parLocationSuffix}'
  properties: {
    resource: {
      id: 'orders-prod-${parLocationSuffix}'
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
    name: 'cosmos-dns-link-${parLocationSuffix}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: refHubvirtualNetwork.id
      }
    }
  }

//Create the Private endpoint
// Private Endpoint for the Storage Account, using the main subnet
resource resCosmosprivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
    name: 'pe-${resCosmosDbAccount.name}'
    location: parlocation
    properties: {
      subnet: {
        id: refHubvirtualNetwork.properties.subnets[1].id
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
    name: 'pe-dnsgroup-cosmos-${parLocationSuffix}'
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



/******************
* Output
******************/
output outCosmosAccountName string = resCosmosDbAccount.name
output outCosmosDBName string = resSqlDb.name
output outCosmosSQLContainerName string = resSqlContainerName.name



