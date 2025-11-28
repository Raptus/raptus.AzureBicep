// Parameters
@description('The name of the Key Vault')
param keyVaultName string = 'RaptusKV'

@description('The Azure region where the Key Vault will be deployed')
param location string = resourceGroup().location

@description('The Azure AD tenant ID for the Key Vault')
param tenantId string = subscription().tenantId

@description('Specifies whether Azure Virtual Machines are permitted to retrieve secrets')
param enabledForDeployment bool = false

@description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets')
param enabledForDiskEncryption bool = false

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets')
param enabledForTemplateDeployment bool = true

@description('SKU of the Key Vault (standard or premium)')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('Object ID of the user or service principal to grant access')
param objectId string = ''

// Key Vault Resource
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
  }
}

// Optional: Add RBAC role assignment if objectId is provided
resource keyVaultSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(objectId)) {
  name: guid(keyVault.id, objectId, 'Key Vault Secrets Officer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: objectId
    principalType: 'User'
  }
}

// Outputs
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
