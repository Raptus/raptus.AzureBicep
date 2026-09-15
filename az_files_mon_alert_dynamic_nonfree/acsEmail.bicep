@description('Optional. Resource group of an existing ACS Communication Service to reuse. Leave empty to create a new ACS Email setup with an Azure-managed domain.')
param existingAcsResourceGroupName string = ''

@description('Optional. Name of an existing ACS Communication Service to reuse. Required together with existingAcsResourceGroupName.')
param existingAcsResourceName string = ''

@description('Optional. Sender address to use with an existing ACS resource (e.g. alerts@customerdomain.com). Required when existingAcsResourceGroupName/existingAcsResourceName are set.')
param existingSenderAddress string = ''

@description('ACS data residency for a newly created ACS setup (not used when reusing an existing resource). Not changeable after the resource exists — choose deliberately per customer.')
param dataLocation string = 'Europe'

// isExisting uses && (short-circuit) rather than parsing a single
// resourceId with split()/array-indexing: Bicep's ternary operator does
// NOT short-circuit for array indexing (both branches get evaluated),
// so split('', '/')[n] on an empty string would throw an out-of-bounds
// error on every default (no-existing-resource) deployment. Two plain
// string params avoid that class of bug entirely.
var isExisting = !empty(existingAcsResourceGroupName) && !empty(existingAcsResourceName)

module emailService 'br/public:avm/res/communication/email-service:0.4.5' =
  if (!isExisting) {
    name: 'storage-monitor-email-service'
    params: {
      name: 'ecs-storage-monitor'
      dataLocation: dataLocation
      domains: [
        {
          name: 'AzureManagedDomain'
          domainManagement: 'AzureManaged'
        }
      ]
    }
  }

module communicationService 'br/public:avm/res/communication/communication-service:0.5.0' =
  if (!isExisting) {
    name: 'storage-monitor-communication-service'
    params: {
      name: 'acs-storage-monitor'
      dataLocation: dataLocation
      linkedDomains: [
        emailService!.outputs.domainResourceIds[0]
      ]
    }
  }

resource existingCommunicationService 'Microsoft.Communication/communicationServices@2025-09-01' existing = if (isExisting) {
    scope: resourceGroup(existingAcsResourceGroupName)
    name: existingAcsResourceName
  }

output acsResourceId string = (isExisting
  ? existingCommunicationService!.id
  : communicationService!.outputs.resourceId)

output acsResourceGroupName string = (isExisting
  ? existingAcsResourceGroupName
  : resourceGroup().name)

output acsResourceName string = (isExisting
  ? existingAcsResourceName
  : communicationService!.outputs.name)

output acsEndpoint string = (isExisting
  ? 'https://${existingCommunicationService!.properties.hostName}'
  : 'https://${communicationService!.outputs.endpoint}')

// DoNotReply is the default sender username Azure provisions
// automatically for every ACS Email domain (managed or custom) — no
// separate senderUsernames resource is needed to use it (verified via
// Microsoft Q&A: "you can only send emails from the address
// DoNotReply@yourdomain.com" by default, until additional MailFrom
// addresses are explicitly added).
output senderAddress string = (isExisting
  ? existingSenderAddress
  : 'DoNotReply@${emailService!.outputs.domainFromSenderDomains[0]}')
