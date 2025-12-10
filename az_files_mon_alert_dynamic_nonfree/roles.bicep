targetScope = 'subscription'

param principalId string

// 1. Reader (To list accounts and shares)
var readerRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

// 2. Monitoring Reader (To read 'FileCapacity' metric)
var monitoringReaderRole = '43d0d8ad-25c7-4714-9337-8ba259a9fe05'

resource roleAssignmentReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, readerRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentMonitor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, monitoringReaderRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', monitoringReaderRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
