param actionGroupId string
param region string
param threshold int

resource metricAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-files-low-free-space-${region}'
  location: 'global'
  properties: {
    severity: 1 // Severity 1 = Error/Warning
    enabled: true
    description: 'Alerts when File Share usage is within the defined buffer of the Quota (High Usage).'
    scopes: [
      subscription().id
    ]
    targetResourceType: 'Microsoft.Storage/storageAccounts'
    targetResourceRegion: region
    evaluationFrequency: 'PT1H'
    windowSize: 'PT1H'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighFileUsage'
          metricName: 'FileCapacity'
          metricNamespace: 'Microsoft.Storage/storageAccounts/fileServices'
          operator: 'GreaterThan'
          threshold: threshold
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
      }
    ]
  }
}
