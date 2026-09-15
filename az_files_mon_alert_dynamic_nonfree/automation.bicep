param location string

param thresholdGB int
param runbookSourceUrl string
param companyName string
param acsEndpoint string
param senderAddress string
param alertRecipientAddress string
param sendTestEmail string = 'false'

// Default: tomorrow's date at 03:00 UTC, which is 05:00 local time in
// Switzerland (W. Europe Standard Time) ONLY while CEST/DST is active
// (UTC+2, roughly late March-late October). Bicep has no timezone-aware
// date arithmetic, so this default drifts by 1h outside DST (would land
// at 04:00 local instead of 05:00) — override explicitly with
// scheduleStartTime="...T04:00:00Z" during CET (winter) if exact 05:00
// alignment matters, or redeploy once after the next DST changeover.
param scheduleStartTime string = '${take(dateTimeAdd(utcNow(), 'P1D'), 10)}T03:00:00Z'

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
        name: 'az-file-alert-mon-run-daily-5am'
        frequency: 'Day'
        interval: 1
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

// NOTE (2026-09-15): discovered live against a real Automation Account
// that Azure Automation's jobSchedules resource does not support
// idempotent redeploy at all — re-PUTting an unchanged, already-existing
// jobSchedule fails with Conflict, and once a specific jobSchedule GUID
// has ever existed and been deleted, that exact GUID is permanently
// unusable again (confirmed via direct REST test), even though a fresh
// GUID for the identical runbook+schedule pair works immediately. This
// is a long-standing (since ~2018), undocumented-as-fixed Azure platform
// limitation, not something fixable purely in Bicep. Renaming the
// schedule (see above, now 'az-file-alert-mon-run-daily-5am') changes
// this resource's guid() seed and sidesteps the tombstoned GUID from the
// prior 8h schedule — it does NOT fix the underlying non-redeployability
// of this resource type; any future schedule/runbook name change will
// need the same treatment.
resource jobSchedule 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  parent: autoAccount
  name: guid(autoAccount.id, 'Check-Storage-Quota', 'az-file-alert-mon-run-daily-5am')
  properties: {
    runbook: {
      name: 'Check-Storage-Quota'
    }
    schedule: {
      name: 'az-file-alert-mon-run-daily-5am'
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
