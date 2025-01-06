/******************
* Containers Bicep File
******************/

/******************
* Parameters
******************/
@description('Location of the deployment')
@allowed([
  'uksouth'
  'northeurope'
])
param location string = 'uksouth'
@allowed([
  'uks'
  'ne'
])
param parprefix string = 'uks'
param parHubVNET string = 'vnet-hub-uks'

/******************
* Variables
******************/

/******************
* References
******************/
//Create reference to spoke RG vnet from the object
resource refHubVnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: parHubVNET
}

/******************
* Resources
******************/
//Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: 'acrprod${parprefix}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

//Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-prod-${parprefix}-${substring(uniqueString(resourceGroup().id), 0, 5)}'
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource resContainerkeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: 'acrAdminPassword'
  properties: {
    value: containerRegistry.listCredentials().passwords[0].value
  }
}

//create Log Analytis Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: 'law-prod-hub-${parprefix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'container-env-${parprefix}'
  location: location
  properties: {
    vnetConfiguration: {
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listkeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {name:'Consumption'
      workloadProfileType: 'consumption'}
    ]
  }
}

/******************
* Output
******************/

output outContainerRegistryName string = containerRegistry.name
output outContainerRegistryUser string = containerRegistry.name
output outContainerRegistrySecretId string = resContainerkeyVaultSecret.id
output outContainerRegistrySecretname string = resContainerkeyVaultSecret.name
output outKeyVaultHubName string = keyVault.name
output apiUrl string = containerEnv.properties.defaultDomain
