targetScope = 'subscription'

param principalId string

// Role Definition IDs (Hardcoded Azure Standards)
var readerRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var keyOperatorRole = '81a9662b-bebf-436f-a333-f67b29880f12'

// 1. Reader Role Assignment
resource roleAssignmentReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, readerRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// 2. Storage Account Key Operator Assignment
resource roleAssignmentKeys 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, keyOperatorRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyOperatorRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
