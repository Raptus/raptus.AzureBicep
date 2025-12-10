param location string
param emailRecipient string

// 1. API Connection (Office 365)
resource office365Connection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'office365-connection'
  location: location
  properties: {
    displayName: 'Office 365 Email'
    // Generic Office 365 API in the according region
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

// 2. Workflow (Logic App)
resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'la-storage-alerter'
  location: location
  properties: {
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                Subject: { type: 'string' }
                Body: { type: 'string' }
              }
            }
          }
        }
      }
      actions: {
        Send_an_email_V2: {
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: {
              To: emailRecipient
              Subject: '@triggerBody()?[\'Subject\']'
              Body: '<p>@{triggerBody()?[\'Body\']}</p>'
            }
            path: '/v2/Mail'
          }
        }
      }
    }
    // Connect Workflow with Connection Ressource
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.id
            connectionName: 'office365-connection'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
  }
}

output logicAppUrl string = listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', 'la-storage-alerter', 'manual'), '2016-06-01').value
