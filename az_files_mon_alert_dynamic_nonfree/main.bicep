targetScope = 'subscription'

@description('The Azure Region for resources.')
param location string = 'switzerlandnorth'

@description('Name of the Resource Group.')
param resourceGroupName string = 'RG-RCHKMONALERT'

@description('The amount of free space (in GB) to alert on. Default is 25GB.')
param freeSpaceThresholdGB int = 25

@description('The email address to receive the alerts.')
param alertEmailAddress string

@description('The Company Name to display in the email subject.')
param companyName string = subscription().displayName

@description('Start time for the scheduler. Default is Now + 2 Hour.')
param scheduleStartTime string = dateTimeAdd(utcNow(), 'PT2H')

@description('The raw URL of the PowerShell script.')
param scriptUrl string = 'https://raw.githubusercontent.com/Raptus/raptus.AzureBicep/refs/heads/main/az_files_mon_alert_dynamic_nonfree/check-quota-storage.ps1'

// --- Resources ---

// 1. Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// 2. Deploy Logic App
module logicApp './logicApp.bicep' = {
  scope: rg
  name: 'deploy-storage-monitor_dynamic_nonfree-logicapp'
  params: {
    location: location
    emailRecipient: alertEmailAddress
  }
}

// 3. Deploy Automation Account
module automation './automation.bicep' = {
  scope: rg
  name: 'deploy-storage-monitor_dynamic_nonfree-automation'
  params: {
    location: location
    logicAppUrl: logicApp.outputs.logicAppUrl
    thresholdGB: freeSpaceThresholdGB
    companyName: companyName
    scheduleStartTime: scheduleStartTime
    runbookSourceUrl: scriptUrl
  }
}

// 4. Deploy Role Assignments
module roleAssignments './roles.bicep' = {
  name: 'deploy-storage-monitor_dynamic_nonfree-roles'
  scope: subscription()
  params: {
    principalId: automation.outputs.identityPrincipalId
  }
}
