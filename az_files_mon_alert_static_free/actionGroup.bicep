param emailAddress string

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-files-freespace'
  location: 'global'
  properties: {
    groupShortName: 'FreeSpace'
    enabled: true
    emailReceivers: [
      {
        name: 'StorageAdmin'
        emailAddress: emailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

output actionGroupId string = actionGroup.id
