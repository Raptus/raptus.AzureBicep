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
param companyName string = tenant().displayName

// Default: tomorrow's date at 03:00 UTC, which is 05:00 local time in
// Switzerland (W. Europe Standard Time) ONLY while CEST/DST is active
// (UTC+2, roughly late March-late October). Bicep has no timezone-aware
// date arithmetic, so this default drifts by 1h outside DST (would land
// at 04:00 local instead of 05:00) — override explicitly with
// scheduleStartTime="...T04:00:00Z" during CET (winter) if exact 05:00
// alignment matters, or redeploy once after the next DST changeover.
// NOTE: this MUST stay identical to automation.bicep's own
// scheduleStartTime default — main.bicep always passes an explicit
// value into that module, so automation.bicep's default is otherwise
// silently unreachable (confirmed live 2026-09-16: an out-of-sync
// default here caused the Thymos AG schedule to start at deployment
// time + 2h instead of the intended daily 05:00).
param scheduleStartTime string = '${take(dateTimeAdd(utcNow(), 'P1D'), 10)}T03:00:00Z'

@description('The raw URL of the PowerShell script.')
param scriptUrl string = 'https://raw.githubusercontent.com/Raptus/raptus.AzureBicep/refs/heads/main/az_files_mon_alert_dynamic_nonfree/check-quota-storage.ps1'

@description('Optional. Resource group of an existing ACS Communication Service to reuse instead of creating a new one. Leave empty to create a new ACS Email setup with an Azure-managed domain.')
param existingAcsResourceGroupName string = ''

@description('Optional. Name of an existing ACS Communication Service to reuse. Required together with existingAcsResourceGroupName.')
param existingAcsResourceName string = ''

@description('Optional. Sender address to use with an existing ACS resource. Required when existingAcsResourceGroupName/existingAcsResourceName are set.')
param existingSenderAddress string = ''

@description('ACS data residency for a newly created ACS setup. Not changeable after the resource exists — choose deliberately per customer. Default matches the spec.')
param dataLocation string = 'Europe'

@description('Forces one alert email with a dummy row on the runbook next run, for end-to-end verification without needing a real low-quota share. Set back to "false" after verifying.')
param sendTestEmail string = 'false'

// --- Resources ---

// 1. Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// 2. Deploy ACS Email (new setup or reuse existing)
module acsEmail './acsEmail.bicep' = {
  scope: rg
  name: 'deploy-storage-monitor_dynamic_nonfree-acsemail'
  params: {
    existingAcsResourceGroupName: existingAcsResourceGroupName
    existingAcsResourceName: existingAcsResourceName
    existingSenderAddress: existingSenderAddress
    dataLocation: dataLocation
  }
}

// 3. Deploy Automation Account
module automation './automation.bicep' = {
  scope: rg
  name: 'deploy-storage-monitor_dynamic_nonfree-automation'
  params: {
    location: location
    acsEndpoint: acsEmail.outputs.acsEndpoint
    senderAddress: acsEmail.outputs.senderAddress
    alertRecipientAddress: alertEmailAddress
    thresholdGB: freeSpaceThresholdGB
    companyName: companyName
    scheduleStartTime: scheduleStartTime
    runbookSourceUrl: scriptUrl
    sendTestEmail: sendTestEmail
  }
}

// 4. Deploy Role Assignments (subscription-scope: Storage roles)
module roleAssignments './roles.bicep' = {
  name: 'deploy-storage-monitor_dynamic_nonfree-roles'
  scope: subscription()
  params: {
    principalId: automation.outputs.identityPrincipalId
  }
}

// 5. Deploy ACS-scoped Role Assignment (resource-group scope: the RG
// that actually holds the ACS resource, new or existing).
// A module's `scope` must be resolvable at the start of the deployment
// (BCP120) — it cannot depend on another module's runtime `outputs`.
// So this is derived directly from this file's OWN params instead of
// from acsEmail.outputs.acsResourceGroupName. The condition below must
// match acsEmail.bicep's own `isExisting` EXACTLY (both params non-empty,
// not just one) — a mismatch here would scope this module at the wrong
// resource group whenever only one of the two existing-* params is set,
// causing the 'existing' lookup inside acsRoleAssignment.bicep to fail
// at deployment time against the wrong resource group.
var acsTargetResourceGroupName = (!empty(existingAcsResourceGroupName) && !empty(existingAcsResourceName))
  ? existingAcsResourceGroupName
  : resourceGroupName

module acsRoleAssignment './acsRoleAssignment.bicep' = {
  scope: resourceGroup(acsTargetResourceGroupName)
  name: 'deploy-storage-monitor_dynamic_nonfree-acsrole'
  params: {
    acsResourceName: acsEmail.outputs.acsResourceName
    principalId: automation.outputs.identityPrincipalId
  }
}
