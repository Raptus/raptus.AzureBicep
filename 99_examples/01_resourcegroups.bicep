targetScope = 'subscription'

@description('Location for all resource groups')
param location string = 'switzerlandnorth'

@description('Name of the Security resource group')
param securityRgName string = 'RG-Security'

@description('Name of the App resource group')
param appRgName string = 'RG-App'

@description('Name of the Service resource group')
param serviceRgName string = 'RG-Service'

// Security Resource Group
resource rgSecurity 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: securityRgName
  location: location
  tags: {
    Environment: 'Production'
    Category: 'Security'
    ManagedBy: 'Raptus AG'
  }
}

// App Resource Group
resource rgApp 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: appRgName
  location: location
  tags: {
    Environment: 'Production'
    Category: 'Application'
    ManagedBy: 'Raptus AG'
  }
}

// Service Resource Group
resource rgService 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: serviceRgName
  location: location
  tags: {
    Environment: 'Production'
    Category: 'Service'
    ManagedBy: 'Raptus AG'
  }
}

// Outputs
output securityRgId string = rgSecurity.id
output appRgId string = rgApp.id
output serviceRgId string = rgService.id
output securityRgName string = rgSecurity.name
output appRgName string = rgApp.name
output serviceRgName string = rgService.name
