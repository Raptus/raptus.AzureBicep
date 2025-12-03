
# Purpose

>**This is a version of the monitoring, that costs nothing. It is limited to ONLY ONE azure files share. You have to set the size manually as parameter and also update, when expanding the storage**

This Bicep Templates deploys an Azure alert stack (Action Group and Alert Rule) for monitoring free disk space on one azure files storages.

### Params:  

- shareQuotaSizeGB = <"total GB of azure files share">
- alertEmailAddress = <"where to send alert - use checkcentral customer email">

## Deploy

	az login
	# Example: Alert if ANY account uses more than 75GB (implying 100GB Quota - 25GB Free)
	az deployment sub create \
	--name "deploy-storage-monitor_static_free" --location switzerlandnorth	--template-file main.bicep --parameters alertEmailAddress="admin@example.com" shareQuotaSizeGB=100

