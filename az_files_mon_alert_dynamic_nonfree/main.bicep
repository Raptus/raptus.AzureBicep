targetScope = 'subscription'

@description('The Azure Region for resources.')
param location string = 'switzerlandnorth'

@description('Name of the Resource Group.')
param resourceGroupName string = 'RG-RCHKMONALERT'

@description('The amount of free space (in GB) to alert on. Default is 25GB.')
param freeSpaceThresholdGB int = 25

@description('The email address to receive the alerts.')
param alertEmailAddress string = 'raptus@checkcentral.cc'

@description('Start time for the scheduler. Default is Now + 1 Hour.')
param scheduleStartTime string = dateTimeAdd(utcNow(), 'PT2H')

// --- Resources ---

// 1. Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// 2. Deploy Logic App
module logicApp './logicApp.bicep' = {
  scope: rg
  name: 'deployLogicApp'
  params: {
    location: location
    emailRecipient: alertEmailAddress
  }
}

// 3. Deploy Automation Account
module automation './automation.bicep' = {
  scope: rg
  name: 'deployAutomation'
  params: {
    location: location
    logicAppUrl: logicApp.outputs.logicAppUrl
    thresholdGB: freeSpaceThresholdGB
    scheduleStartTime: scheduleStartTime
  }
}

// 4. Deploy Role Assignments
module roleAssignments './roles.bicep' = {
  name: 'deployRoles'
  scope: subscription()
  params: {
    principalId: automation.outputs.identityPrincipalId
  }
}
