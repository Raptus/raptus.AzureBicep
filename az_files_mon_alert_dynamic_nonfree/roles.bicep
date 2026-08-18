targetScope = 'subscription'

param principalId string

// Role Definition IDs (Hardcoded Azure Standards)
var readerRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

// 1. Reader Role Assignment
// Sufficient for Get-AzRmStorageShare -GetShareUsage (ARM management plane).
// No Storage Account Key Operator role needed: the runbook no longer reads/regenerates Storage Account keys.
resource roleAssignmentReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, readerRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
