param location string
param logicAppUrl string
param thresholdGB int
param runbookSourceUrl string
param companyName string

// Default: Current UTC time + 1 Hour (To ensure it is in the future)
// If you want exact 16:00 alignment, override this parameter.
param scheduleStartTime string = dateTimeAdd(utcNow(), 'PT2H')

// This helps creating a unique deployment GUID every time the deployment runs
param deploymentTimestamp string = utcNow()

// Create Automation Account
resource autoAccount 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: 'aa-storage-monitor'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

// Variable: Store the Logic App Webhook URL
resource variableLogicApp 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: autoAccount
  name: 'LogicAppWebhookUrl'
  properties: {
    value: '"${logicAppUrl}"'
    isEncrypted: true
  }
}

// Variable: Store the Threshold
resource variableThreshold 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: autoAccount
  name: 'FreeSpaceThresholdGB'
  properties: {
    value: '${thresholdGB}'
    isEncrypted: false
  }
}

// Variable: Company Name
resource variableCompany 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: autoAccount
  name: 'CompanyName'
  properties: {
    value: '"${companyName}"'
    isEncrypted: false
  }
}

// Create the Runbook Container (Empty Shell)
resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = {
  parent: autoAccount
  name: 'Check-Storage-Quota'
  location: location
  properties: {
    runbookType: 'PowerShell72'
    logVerbose: false
    logProgress: false
    description: 'Checks Azure Files Quota vs Usage'
    // This automates the publishing
    publishContentLink: {
      uri: runbookSourceUrl
      version: '1.0.0.0'
    }
  }
}

// Create the Schedule (Every 8h, starting 16:00 Swiss Time)
resource schedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  parent: autoAccount
  name: 'az-file-alert-mon-run-every-8h'
  properties: {
    frequency: 'Hour'
    interval: 8
    // Start in the past
    startTime: scheduleStartTime
    timeZone: 'W. Europe Standard Time' 
  }
}

// Link Runbook to Schedule
resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  parent: autoAccount
  name: guid(autoAccount.id, 'az-file-alert-mon-run-every-8h', 'Check-Storage-Quota', deploymentTimestamp)
  properties: {
    runbook: {
      name: runbook.name
    }
    schedule: {
      name: schedule.name
    }
    parameters: {} 
  }
}

// Export the Identity ID for Role Assignments
output identityPrincipalId string = autoAccount.identity.principalId
