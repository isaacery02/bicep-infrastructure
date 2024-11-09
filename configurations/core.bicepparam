using '../infrastructure/core.bicep'

param parlocation = 'uksouth'
param parprefix = 'uks'
param parVNETName = 'hub'
param parhubvnetSettings = {
  addressPrefix: [
    '10.0.0.0/16'
  ]
  subnets: [
    {
      name: 'subnetProdHub'
      addressPrefix: '10.0.1.0/24'
    }
    {
      name: 'subnetIntegHub'
      addressPrefix: '10.0.2.0/24'
    }
  ]
}

