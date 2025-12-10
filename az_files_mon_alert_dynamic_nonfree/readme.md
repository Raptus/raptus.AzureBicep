
# Purpose

>**This is a version of the monitoring, that costs a few cents per month, depending on the amount of storages to monitor. This automatically checks every premium or files type account for free space and sends an alert**

This Bicep Templates deploys an Azure automation account combined with a logic app for monitoring free disk space on all azure files and premium storages.

### Params:  

- freeSpaceThresholdGB=<"<integer> - when free space smaller, send an alert"> - **defaults to 25GB if not defined**
- alertEmailAddress="donotreply@domain.tld" - **set the customer checkcentral email address**
- scheduleStartTime="2025-12-03T18:00:00+01:00" - set according to you needs - **defaults to 2h in the future**

## Deploy

### 1. Deploy

	az login
	az deployment sub create --name "deploy-storage-monitor_dynamic_nonfree" --location switzerlandnorth --template-file main.bicep	--parameters alertEmailAddress="<donotreply@domain.tld>" [freeSpaceThresholdGB=50] [scheduleStartTime="2025-12-03T16:00:00+01:00"] [companyName="Contoso Corp"]

### 2. Authorize

- Go to Azure Portal -> Resource Group "RG-RCHKMONALERT"
- Find the API Connection office365-connection (Status: Error)
- Click Edit API connection -> Authorize -> Sign in -> Save

### 3. You can change quota and naming setting

- Go to Azure Portal -> Resource Group "RG-RCHKMONALERT"
- Find the Automation aa-storage-monitor
- Click on "Shared Resources" -> "Variables"