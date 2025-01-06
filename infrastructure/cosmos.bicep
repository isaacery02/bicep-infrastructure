/*************
* Purpose of this file
* 
*************/


/*******************
* Parameters
*******************/


/*******************
* Variables
*******************/


/*******************
* References
*******************/


/*******************
* Modules
*******************/
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

resource resSqlContainerName 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-06-15' = {
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



/******************
* Output
******************/
output outCosmosAccountName string = resCosmosDbAccount.name
output outCosmosDBName string = resSqlDb.name
output outCosmosSQLContainerName string = resSqlContainerName.name
output outvnethubName string = resHubvirtualNetwork.name
output outLocationSuffix string = varLocationSuffix

/******************
* Output
******************/


