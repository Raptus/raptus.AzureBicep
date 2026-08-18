# 1. Connect using the Managed Identity (Bicep deployed this)
Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Identity

# 2. Retrieve Configuration
$LogicAppUrl = Get-AutomationVariable -Name 'LogicAppWebhookUrl'
$ThresholdGB = Get-AutomationVariable -Name 'FreeSpaceThresholdGB'
$Results = @()

# 3. Get All Storage Accounts in Subscription
$StorageAccounts = Get-AzStorageAccount

ForEach ($Account in $StorageAccounts) {
    Try {
        # Get All File Shares via ARM (management plane, no Storage Account Keys needed)
        $Shares = Get-AzRmStorageShare -ResourceGroupName $Account.ResourceGroupName -StorageAccountName $Account.StorageAccountName -ErrorAction SilentlyContinue

        ForEach ($Share in $Shares) {
            # -GetShareUsage only works per single share, not on the list call above
            $ShareUsage = Get-AzRmStorageShare -ResourceGroupName $Account.ResourceGroupName -StorageAccountName $Account.StorageAccountName -Name $Share.Name -GetShareUsage -ErrorAction SilentlyContinue

            # Calculate Free Space
            # Note: Quota is in GiB. Usage is returned in Bytes, converted to GB.
            $UsedGB = [math]::Round($ShareUsage.ShareUsageBytes / 1GB, 2)
            $QuotaGB = $Share.QuotaGiB
            $FreeSpace = $QuotaGB - $UsedGB
            
            if ($FreeSpace -lt $ThresholdGB) {
                Write-Output "ALERT: $($Account.StorageAccountName)/$($Share.Name) has only $FreeSpace GB free."
                
                $Results += [PSCustomObject]@{
                    Account   = $Account.StorageAccountName
                    Share     = $Share.Name
                    QuotaGB   = $QuotaGB
                    UsedGB    = $UsedGB
                    FreeGB    = $FreeSpace
                }
            }
        }
    }
    Catch {
        Write-Error "Failed to check account $($Account.StorageAccountName): $_"
    }
}

# 4. If we found issues, trigger the Logic App
If ($Results.Count -gt 0) {
    $TableHtml = $Results | ConvertTo-Html -Fragment
    $Payload = @{
        Subject = "Azure Storage Capacity Alert: $($Results.Count) Shares Low on Space"
        Body    = "The following shares have less than $ThresholdGB GB free space:<br><br>$TableHtml"
    }
    
    Invoke-RestMethod -Uri $LogicAppUrl -Method Post -Body ($Payload | ConvertTo-Json) -ContentType "application/json"
}