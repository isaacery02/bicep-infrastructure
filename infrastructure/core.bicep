/******************
* Core Network Bicep File
******************/

/******************
* Parameters
******************/
@description('Location of the deployment')
param parlocation string = 'uksouth'
@allowed([
  'uks'
  'ne'
])
param parprefix string = 'uks'
param parVNETName string = 'hub'
@description('CIDR Ranges for the vnet')
param parhubvnetSettings object

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

/******************
* Output
******************/
output outvnethubName string = resHubvirtualNetwork.name
output outLocationSuffix string = varLocationSuffix

