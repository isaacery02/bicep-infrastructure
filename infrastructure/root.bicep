targetScope = 'subscription'

/*************
* Container Apps with Cosmos DB, KVs 
* 
*************/
/*******************
* Parameters
*******************/
param parlocation string = 'uksouth'
param parprefix string = 'uks'
param parVNETName string = 'hub'
param parhubvnetSettings object

//Create reference to Hub RG from the object
resource refHubResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  scope: subscription()
  name: 'rg-prod-hub-uks'
}

/*******************
* Modules
*******************/
// Create Hub VNET NSG and Cosmos
module modHubVNET 'core.bicep' = {
  scope: refHubResourceGroup
  name: 'HubCoreDeployment'
  params: {
    parVNETName: parVNETName
    parlocation: parlocation
    parprefix: parprefix
    parhubvnetSettings: parhubvnetSettings
  }
}

// Create KV, Azure Container apps environment, LAW
module modContainerApps 'containers.bicep' = {
  scope: refHubResourceGroup
  name: 'ProdContainerDeployment'
  params: {
    parHubVNET : modHubVNET.outputs.outvnethubName
  }
}

// Deploy APM
module modAPM 'apm.bicep' = {
  scope: refHubResourceGroup
  name: 'ProdAPMDeployment'
  params: {
    location: parlocation
    prefix: modHubVNET.outputs.outLocationSuffix
  }
}

/******************
* Output
******************/


