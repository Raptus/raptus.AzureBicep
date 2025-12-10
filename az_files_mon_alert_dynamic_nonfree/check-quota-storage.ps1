# 1. Connect using Managed Identity
try {
    Disable-AzContextAutosave -Scope Process
    Connect-AzAccount -Identity
}
catch {
    Write-Error "Failed to login. Ensure 'Reader' and 'Storage File Data Privileged Reader' roles are assigned."
    throw $_
}

# 2. Get Config
try {
    $LogicAppUrl = Get-AutomationVariable -Name 'LogicAppWebhookUrl'
    $ThresholdGB = Get-AutomationVariable -Name 'FreeSpaceThresholdGB'
}
catch {
    Write-Error "Failed to retrieve variables."
    throw $_
}

$Results = @()

# 3. Scan Accounts
$StorageAccounts = Get-AzStorageAccount

ForEach ($Account in $StorageAccounts) {
    Try {
        # NEW: Create Context using the Managed Identity (OAuth)
        # This bypasses the MAC Signature/Key error completely.
        $Ctx = New-AzStorageContext -StorageAccountName $Account.StorageAccountName -UseConnectedAccount
        
        # Get Shares using the OAuth Context
        $Shares = Get-AzStorageShare -Context $Ctx -ErrorAction SilentlyContinue
        
        ForEach ($Share in $Shares) {
            # Get Usage
            $Stats = Get-AzStorageShareUsage -Context $Ctx -ShareName $Share.Name -ErrorAction SilentlyContinue
            
            if ($Stats -ne $null) {
                $UsedGB = $Stats.Usage
                $QuotaGB = $Share.Quota
                $FreeSpace = $QuotaGB - $UsedGB
                
                if ($FreeSpace -lt $ThresholdGB) {
                    Write-Output "ALERT: $($Account.StorageAccountName)/$($Share.Name) has only $FreeSpace GB free."
                    
                    $Results += [PSCustomObject]@{
                        Account = $Account.StorageAccountName
                        Share   = $Share.Name
                        QuotaGB = $QuotaGB
                        UsedGB  = $UsedGB
                        FreeGB  = $FreeSpace
                    }
                }
            }
        }
    }
    Catch {
        # Often occurs if the Identity doesn't have permissions on a specific storage account 
        # (e.g., if it's in a different subscription or firewalled)
        Write-Warning "Skipping $($Account.StorageAccountName): $_"
    }
}

# 4. Send Alert
If ($Results.Count -gt 0) {
    $TableHtml = $Results | ConvertTo-Html -Fragment
    $Payload = @{
        Subject = "Storage Alert: Low Free Space (< $ThresholdGB GB)"
        Body    = "<h3>Low Storage Space Detected</h3>$TableHtml"
    }
    Invoke-RestMethod -Uri $LogicAppUrl -Method Post -Body ($Payload | ConvertTo-Json) -ContentType "application/json"
}