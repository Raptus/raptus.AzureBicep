# Purpose

>**This is a version of the monitoring, that costs a few cents per
>month, depending on the amount of storages to monitor. This
>automatically checks every premium or files type account for free
>space and sends an alert.**

This Bicep template deploys an Azure Automation Account (quota check
and alerting logic) together with Azure Communication Services (ACS)
Email for monitoring free disk space on all Azure Files and Premium
Storage accounts. Email sending is fully automated — no Microsoft
365/Exchange Online mailbox and no manual post-deployment authorization
step are required.

The runbook runs **once daily at 05:00** (Europe/Zurich) and sends an
email on **every run**, not only when a problem is found — a "Storage
Account Check OK" heartbeat email on healthy runs, an alert email
otherwise. This is intentional: it lets external dead-man's-switch
monitoring (e.g. Checkcentral) watch this mailbox for a missing daily
email, rather than only reacting to an alert that may never come if the
runbook itself silently stops running.

## Params

- `freeSpaceThresholdGB` = `<integer>` — alert when free space drops
  below this value. **Defaults to 25GB if not defined.**
- `alertEmailAddress` = `"you@example.com"` — the alert recipient
  address.
- `scheduleStartTime` = `"2025-12-03T05:00:00+01:00"` — first run
  timestamp; recurrence is daily from there. **Defaults to tomorrow at
  03:00 UTC**, which is 05:00 local time only while CEST/DST is active
  (UTC+2). Bicep cannot do timezone-aware date math, so during CET
  (winter, UTC+1) this default lands at 04:00 local — override
  explicitly (`...T04:00:00Z`) if exact 05:00 alignment matters, or just
  redeploy once after the next DST changeover.
- `companyName` = `"Contoso Corp"` — shown in the email subject.
  **Defaults to `tenant().displayName`.**
- `dataLocation` = `"Europe"` — ACS data residency for a newly created
  ACS setup. **Defaults to `Europe`**; not changeable after the ACS
  resource exists, so pick deliberately for the target customer.
- `existingAcsResourceGroupName` / `existingAcsResourceName` /
  `existingSenderAddress` — optional, all three together, to reuse an
  already-existing ACS Communication Service (e.g. a shared
  `RG-EMAILRELAY` resource) instead of creating a new one. **Leave all
  three empty for the default behaviour (new, isolated ACS setup per
  customer) — this is the only path deployment-tested so far.** See
  "Reusing an existing ACS resource" below before using this.
- `sendTestEmail` = `"true"` / `"false"` — forces one alert email with
  a dummy row on the runbook's next run, useful for a first end-to-end
  verification without needing a real low-quota share. **Defaults to
  `"false"`; remember to set it back to `"false"` afterwards.**

## Deploy

### 1. Push the runbook script first

The Automation Account runbook is loaded from a GitHub raw URL
(`scriptUrl`, defaults to this repo's `main` branch) **at deployment
time** — Azure fetches whatever is currently on that branch. Push any
local changes to `check-quota-storage.ps1` to `main` **before**
deploying, or the Automation Account will run a stale/mismatched script
version against the newly deployed Bicep resources.

### 2. Deploy

```bash
az login
az deployment sub create --name "deploy-storage-monitor_dynamic_nonfree" --location switzerlandnorth --template-file main.bicep --parameters alertEmailAddress="<you@example.com>" [freeSpaceThresholdGB=50] [scheduleStartTime="2025-12-03T16:00:00+01:00"] [companyName="Contoso Corp"]
```

No manual authorization step is required after this — Azure
Communication Services Email is license-free and needs no interactive
sign-in.

### 3. First run may need a few minutes

The Automation Account's Managed Identity is granted its Azure
Communication Services role as part of this same deployment. Azure RBAC
role assignments can take a few minutes to propagate. If the very first
scheduled run happens immediately after deployment, it may fail with an
authentication error — the next scheduled run (or a manually triggered
one, see below) will succeed once the role has propagated.

### 4. Verify end-to-end (recommended before relying on this)

Set `sendTestEmail=true` and either redeploy or update the Automation
Account's `SendTestEmail` variable directly (Portal → Resource Group →
Automation Account `aa-storage-monitor` → Shared Resources →
Variables), then trigger the runbook manually:

```bash
az automation runbook start --automation-account-name aa-storage-monitor --resource-group RG-RCHKMONALERT --name Check-Storage-Quota
```

Confirm the test email arrives, then set `SendTestEmail` back to
`false` so real runs don't always alert.

### 5. You can change quota and naming settings afterwards

- Go to Azure Portal -> Resource Group "RG-RCHKMONALERT"
- Find the Automation Account `aa-storage-monitor`
- Click on "Shared Resources" -> "Variables"

### 6. You can change the receiver email afterwards

- Go to Azure Portal -> Resource Group "RG-RCHKMONALERT"
- Find the Automation Account `aa-storage-monitor`
- Click on "Shared Resources" -> "Variables" -> `AlertRecipientAddress`
- Edit the value to your needs

## Reusing an existing ACS resource

If Raptus already runs an Azure Communication Services resource for
this customer (commonly in a resource group named `RG-EMAILRELAY`, e.g.
already used for newsletter sending), you can point this deployment at
it instead of creating a new, isolated ACS setup: set
`existingAcsResourceGroupName`, `existingAcsResourceName`, and
`existingSenderAddress` (all three together — leaving one empty falls
back silently to creating a new ACS setup instead, without an error).

**This path has not yet been deployment-tested in this repository** —
verify carefully on first use. It also grants this Automation Account's
identity the "Communication and Email Service Owner" role directly on
that shared ACS resource, which is an Owner-level role covering every
verified sender on it, not just this customer's. See
`docs/adr/0001-acs-shared-resource-role-assignment.md` for the
trade-off and required sign-off before using this on a resource shared
across customers.
