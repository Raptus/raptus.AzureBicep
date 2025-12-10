targetScope = 'subscription'

param principalId string

// Role IDs
var readerRole = 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader (Control Plane)
var dataReaderRole = '69566ab7-960f-475b-8e7c-b3118f30e6bd' // Storage File Data Privileged Reader (Data Plane)

// 1. Assign Reader Role (To list accounts)
resource roleAssignmentReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, readerRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

// 2. Assign Data Reader Role (NEW: To read Share Stats via OAuth, no keys needed)
resource roleAssignmentData 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, principalId, dataReaderRole)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', dataReaderRole)
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
