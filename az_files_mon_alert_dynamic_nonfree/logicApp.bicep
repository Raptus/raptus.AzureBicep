param location string
param emailRecipient string

var workflowName = 'la-storage-alerter'

module office365Connection 'br/public:avm/res/web/connection:0.4.4' = {
  name: 'office365-connection'
  params: {
    name: 'office365-connection'
    location: location
    displayName: 'Office 365 Email'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
}

module workflowModule 'br/public:avm/res/logic/workflow:0.6.0' = {
  name: 'storage-alerter-workflow'
  params: {
    name: workflowName
    location: location
    workflowParameters: {
      '$connections': {
        type: 'Object'
        defaultValue: {}
      }
    }
    definitionParameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365Connection.outputs.resourceId
            connectionName: office365Connection.outputs.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
    workflowTriggers: {
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
    workflowActions: {
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
}

// listCallbackUrl() needs a value resolvable at deployment start (BCP181),
// which a module's resourceId output isn't — so we look the trigger up as
// an 'existing' resource by its known (literal) name instead. Targets the
// manual trigger (not the workflow root) at api-version 2016-06-01,
// matching the original hand-written code's behavior exactly.
resource manualTrigger 'Microsoft.Logic/workflows/triggers@2016-06-01' existing = {
  name: '${workflowName}/manual'
  dependsOn: [
    workflowModule
  ]
}

@secure()
output logicAppUrl string = manualTrigger.listCallbackUrl().value
