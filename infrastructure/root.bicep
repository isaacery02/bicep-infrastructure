targetScope = 'subscription'

/*************
* Container Apps with Cosmos DB, KVs 
* 
*************/

//Create reference to Hub RG from the object
resource refHubResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  scope: subscription()
  name: 'rg-prod-hub-uks'
}

/*******************
* Modules
*******************/
// Create VNET NSG and Cosmos
module modHubVNET 'core.bicep' = {
  scope: refHubResourceGroup
  name: 'HubCoreDeployment'
  params: {
  }
}

// Create KV, Azure Container apps
module modContainerApps 'containers.bicep' = {
  scope: refHubResourceGroup
  name: 'ProdContainerDeployment'
  params: {
  }
}


