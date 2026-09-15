targetScope = 'resourceGroup'

param acsResourceName string
param principalId string

// Built-in role, required exactly as named — Azure Communication
// Services does not support custom IAM roles (confirmed via Microsoft
// Q&A community reference). Role definition ID verified against
// azadvertizer.net's built-in role catalog.
var communicationEmailServiceOwnerRoleId = '09976791-48a7-449e-bb21-39d1a415f350'

resource acs 'Microsoft.Communication/communicationServices@2025-09-01' existing = {
  name: acsResourceName
}

resource roleAssignmentAcsEmail 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acs.id, principalId, communicationEmailServiceOwnerRoleId)
  scope: acs
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      communicationEmailServiceOwnerRoleId
    )
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
