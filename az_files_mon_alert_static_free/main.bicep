targetScope = 'subscription'

// --- Parameters ---
@description('Email address for the alert notifications.')
param alertEmailAddress string

@description('The region for the Resource Group metadata (e.g., switzerlandnorth, westeurope).')
param mainRegion string = 'switzerlandnorth'

@description('The Quota size of your File Shares in GB. (e.g., 100 or 5120 for 5TB).')
param shareQuotaSizeGB int = 100 

@description('The amount of free space (buffer) in GB to alert on. Default is 25GB.')
param freeSpaceBufferGB int = 25

@description('List of regions where you have Storage Accounts.')
param targetRegions array = [
  'switzerlandnorth'
  'westeurope'
]

// --- Math: Invert "Free Space" to "Used Space Threshold" ---
// 1 GB = 1,073,741,824 Bytes
var bytesPerGB = 1073741824
// If Quota is 100GB and Buffer is 25GB, we alert at 75GB Used.
var thresholdBytes = (shareQuotaSizeGB - freeSpaceBufferGB) * bytesPerGB

// --- Resources ---

// 1. Create the specific Resource Group
resource rgMonitor 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'RG-RCHKMONALERT'
  location: mainRegion
}

// 2. Deploy Action Group (Email)
module actionGroupModule './actionGroup.bicep' = {
  scope: rgMonitor
  name: 'deployActionGroup'
  params: {
    emailAddress: alertEmailAddress
  }
}

// 3. Deploy Alert Rules (Per Region)
module alertRulesModule './alertRule.bicep' = [for region in targetRegions: {
  scope: rgMonitor
  name: 'deployAlert-${region}'
  params: {
    actionGroupId: actionGroupModule.outputs.actionGroupId
    region: region
    threshold: thresholdBytes
  }
}]
