param location string
param logicAppUrl string
param thresholdGB int

// Default: Current UTC time + 1 Hour (To ensure it is in the future)
// If you want exact 18:00 alignment, override this parameter.
param scheduleStartTime string = dateTimeAdd(utcNow(), 'PT2H')

// 1. Create Automation Account
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

// 2. Variable: Store the Logic App Webhook URL
resource variableLogicApp 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: autoAccount
  name: 'LogicAppWebhookUrl'
  properties: {
    value: '"${logicAppUrl}"'
    isEncrypted: true
  }
}

// 3. Variable: Store the Threshold
resource variableThreshold 'Microsoft.Automation/automationAccounts/variables@2022-08-08' = {
  parent: autoAccount
  name: 'FreeSpaceThresholdGB'
  properties: {
    value: '${thresholdGB}'
    isEncrypted: false
  }
}

// 4. Create the Runbook Container (Empty Shell)
resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = {
  parent: autoAccount
  name: 'Check-Storage-Quota'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: false
    description: 'Checks Azure Files Quota vs Usage'
  }
}

// 5. Create the Schedule (Every 6h, starting 18:00 Swiss Time)
resource schedule 'Microsoft.Automation/automationAccounts/schedules@2022-08-08' = {
  parent: autoAccount
  name: 'run-every-6h'
  properties: {
    frequency: 'Hour'
    interval: 6
    // Start in the past at 18:00 to anchor the cycle (12:00, 18:00, 00:00, 06:00)
    startTime: scheduleStartTime
    timeZone: 'W. Europe Standard Time' 
  }
}

// 6. Link Runbook to Schedule
resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  parent: autoAccount
  name: guid(autoAccount.id, 'run-every-6h', 'Check-Storage-Quota')
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
