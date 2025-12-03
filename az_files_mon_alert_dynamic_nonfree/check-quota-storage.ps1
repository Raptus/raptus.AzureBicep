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
        # Get Keys to authenticate (Generic method that works for Standard & Premium)
        $Keys = Get-AzStorageAccountKey -ResourceGroupName $Account.ResourceGroupName -Name $Account.StorageAccountName
        $Ctx = New-AzStorageContext -StorageAccountName $Account.StorageAccountName -StorageAccountKey $Keys[0].Value
        
        # Get All File Shares
        $Shares = Get-AzStorageShare -Context $Ctx -ErrorAction SilentlyContinue
        
        ForEach ($Share in $Shares) {
            # Get Usage Stats (Works for Standard too)
            $Stats = Get-AzStorageShareUsage -Context $Ctx -ShareName $Share.Name -ErrorAction SilentlyContinue
            
            # Calculate Free Space
            # Note: Quota is in GB. Usage is in GB (rounded).
            $UsedGB = $Stats.Usage
            $QuotaGB = $Share.Quota
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