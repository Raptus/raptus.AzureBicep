param location string

param thresholdGB int
param runbookSourceUrl string
param companyName string
param acsEndpoint string
param senderAddress string
param alertRecipientAddress string
param sendTestEmail string = 'false'

// Default: Current UTC time + 1 Hour (To ensure it is in the future)
// If you want exact 16:00 alignment, override this parameter.
param scheduleStartTime string = dateTimeAdd(utcNow(), 'PT2H')

module automationAccountModule 'br/public:avm/res/automation/automation-account:0.19.2' = {
  name: 'storage-monitor-automation-account'
  params: {
    name: 'aa-storage-monitor'
    location: location
    skuName: 'Basic'
    disableLocalAuth: false
    managedIdentities: {
      systemAssigned: true
    }
    variables: [
      {
        name: 'FreeSpaceThresholdGB'
        value: '${thresholdGB}'
        isEncrypted: false
      }
      {
        name: 'CompanyName'
        value: '"${companyName}"'
        isEncrypted: false
      }
      {
        name: 'AcsEndpoint'
        value: '"${acsEndpoint}"'
        isEncrypted: false
      }
      {
        name: 'SenderAddress'
        value: '"${senderAddress}"'
        isEncrypted: false
      }
      {
        name: 'AlertRecipientAddress'
        value: '"${alertRecipientAddress}"'
        isEncrypted: false
      }
      {
        name: 'SendTestEmail'
        value: '"${sendTestEmail}"'
        isEncrypted: false
      }
    ]
    runbooks: [
      {
        name: 'Check-Storage-Quota'
        type: 'PowerShell72'
        description: 'Checks Azure Files Quota vs Usage'
        uri: runbookSourceUrl
        version: '1.0.0.0'
      }
    ]
    schedules: [
      {
        name: 'az-file-alert-mon-run-every-8h'
        frequency: 'Hour'
        interval: 8
        startTime: scheduleStartTime
        timeZone: 'W. Europe Standard Time'
      }
    ]
  }
}

// AVM 0.19.2's jobSchedules array defaults the resource's own name to
// newGuid() internally (verified against the compiled ARM template) and
// never lets a caller override it — that reproduces the exact
// non-deterministic-naming bug the AVM migration existed to fix.
// Declared by hand instead, with a deterministic name, against an
// 'existing' lookup of the AVM-created account. (Unchanged from the AVM
// migration fix wave — unrelated to this ACS migration.)
resource autoAccount 'Microsoft.Automation/automationAccounts@2022-08-08' existing = {
  name: 'aa-storage-monitor'
  dependsOn: [
    automationAccountModule
  ]
}

resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  parent: autoAccount
  name: guid(autoAccount.id, 'Check-Storage-Quota', 'az-file-alert-mon-run-every-8h')
  properties: {
    runbook: {
      name: 'Check-Storage-Quota'
    }
    schedule: {
      name: 'az-file-alert-mon-run-every-8h'
    }
    parameters: {}
  }
  dependsOn: [
    automationAccountModule
  ]
}

// Export the Identity ID for Role Assignments
// Non-null assertion (!): the module's output is typed nullable (string?)
// to cover the general case where system-assigned identity isn't
// configured — we know it's always populated here since we pass
// managedIdentities: { systemAssigned: true } above.
output identityPrincipalId string = automationAccountModule.outputs.systemAssignedMIPrincipalId!
