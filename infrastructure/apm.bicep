/*************
* Purpose of this file
* 
*************/


/*******************
* Parameters
*******************/
param location string = 'uksouth'
param prefix string = 'uks'
param parTierApm string = 'Consumption'
param parCapacity int = 0
param parPublisherEmail string = 'isaac.rayner@gmail.com'
param parPublisherName string = 'IsaacRProd'

/*******************
* Variables
*******************/


/*******************
* References
*******************/


/*******************
* Modules
*******************/
// Create APM

resource resApiManagementInstance 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'apm-prod-${prefix}'
  location: location
  sku:{
    capacity: parCapacity
    name: parTierApm
  }
  properties:{
    virtualNetworkType: 'None'
    publisherEmail: parPublisherEmail
    publisherName: parPublisherName
  }
}


/******************
* Output
******************/


