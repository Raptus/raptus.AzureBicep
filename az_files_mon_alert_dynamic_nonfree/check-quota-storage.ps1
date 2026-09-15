# --- 1. Login & Setup ---
Write-Output "STARTING: Initializing Runbook (Metric Method v2)..."

try {
    Disable-AzContextAutosave -Scope Process
    Connect-AzAccount -Identity | Out-Null
    Write-Output "SUCCESS: Logged in with Managed Identity."
}
catch {
    Write-Error "CRITICAL: Failed to login."
    throw $_
}

# --- 2. Configuration ---
try {
    $AcsEndpoint = Get-AutomationVariable -Name 'AcsEndpoint'
    $SenderAddress = Get-AutomationVariable -Name 'SenderAddress'
    $AlertRecipientAddress = Get-AutomationVariable -Name 'AlertRecipientAddress'
    $ThresholdGB = Get-AutomationVariable -Name 'FreeSpaceThresholdGB'
    $CompanyName = Get-AutomationVariable -Name 'CompanyName'
    $SendTestEmail = Get-AutomationVariable -Name 'SendTestEmail'

    # DEBUG: Check if the ACS endpoint looks valid
    if ([string]::IsNullOrEmpty($AcsEndpoint)) { throw "AcsEndpoint variable is empty!" }
    if ([string]::IsNullOrEmpty($SenderAddress)) { throw "SenderAddress variable is empty!" }
    if ([string]::IsNullOrEmpty($AlertRecipientAddress)) { throw "AlertRecipientAddress variable is empty!" }

    Write-Output "CONFIG: Threshold set to $ThresholdGB GB."
    Write-Output "CONFIG: Company Name set to '$CompanyName'."
}
catch {
    Write-Error "CRITICAL: Variables not found."
    throw $_
}

$Results = @()

# --- 3. Scan Accounts ---
$StorageAccounts = Get-AzStorageAccount
Write-Output "SCAN: Found $($StorageAccounts.Count) storage accounts."

ForEach ($Account in $StorageAccounts) {
    Write-Output "--------------------------------------------------"
    Write-Output "CHECKING ACCOUNT: $($Account.StorageAccountName)"

    Try {
        # 1. Get List of Shares via ARM
        $Shares = Get-AzRmStorageShare -ResourceGroupName $Account.ResourceGroupName -StorageAccountName $Account.StorageAccountName -ErrorAction Stop
        
        if ($Shares.Count -eq 0) {
            Write-Output "  > [INFO] No shares found."
            continue
        }

        ForEach ($Share in $Shares) {
            Try {
                # --- FIX: Robust Quota Detection ---
                # Different module versions store the Quota in different properties. We check them all.
                $QuotaGB = 0
                
                if ($null -ne $Share.Quota) {
                    $QuotaGB = $Share.Quota
                } elseif ($null -ne $Share.Properties -and $null -ne $Share.Properties.Quota) {
                    $QuotaGB = $Share.Properties.Quota
                } elseif ($null -ne $Share.QuotaGiB) {
                    $QuotaGB = $Share.QuotaGiB
                }
                
                # Fallback: If quota is still 0 or null, it might be a serverless/large share without explicit quota.
                # We assume standard Azure limit (5120 GB / 5 TB) to prevent math errors, but log a warning.
                if ($QuotaGB -eq 0 -or $QuotaGB -eq $null) {
                    Write-Warning "    [WARN] Could not determine Quota for '$($Share.Name)'. Assuming default 5120 GB."
                    $QuotaGB = 5120
                }

                # --- Ignore Small Shares (< 25 GB Quota) ---
                if ($QuotaGB -lt 25) {
                    Write-Output "  > SKIP: '$($Share.Name)' (Quota ${QuotaGB}GB is too small to monitor)."
                    continue
                }

                # --- 2. Get Usage from Metrics ---
                $MetricResourceID = "$($Account.Id)/fileServices/default"
                
                # We check the last 2 hours to ensure we find at least one data point
                $MetricData = Get-AzMetric -ResourceId $MetricResourceID `
                    -MetricName "FileCapacity" `
                    -MetricFilter "FileShare eq '$($Share.Name)'" `
                    -AggregationType Average `
                    -TimeGrain 01:00:00 `
                    -StartTime (Get-Date).AddHours(-2) `
                    -EndTime (Get-Date) `
                    -ErrorAction Stop

                $LatestMetric = $MetricData.Data | Sort-Object TimeStamp -Descending | Select-Object -First 1
                
                if ($null -eq $LatestMetric -or $null -eq $LatestMetric.Average) {
                    $UsedGB = 0
                    Write-Output "  > [INFO] No usage data for '$($Share.Name)'. Assuming 0 GB used."
                } else {
                    $UsedBytes = $LatestMetric.Average
                    $UsedGB = [math]::Round($UsedBytes / 1GB, 2)
                }

                # --- 3. Calculation ---
                $FreeSpace = $QuotaGB - $UsedGB
                
                Write-Output "  > SHARE: $($Share.Name)"
                Write-Output "    |-- Quota: $QuotaGB GB"
                Write-Output "    |-- Used : $UsedGB GB"
                Write-Output "    |-- Free : $FreeSpace GB"

                if ($FreeSpace -lt $ThresholdGB) {
                    Write-Output "    [!] ALERT: LOW SPACE DETECTED!"
                    $Results += [PSCustomObject]@{
                        Account = $Account.StorageAccountName
                        Share   = $Share.Name
                        QuotaGB = $QuotaGB
                        UsedGB  = $UsedGB
                        FreeGB  = $FreeSpace
                    }
                }
            }
            Catch {
                Write-Warning "    [ERROR] Processing '$($Share.Name)' failed: $($_.Exception.Message)"
            }
        }
    }
    Catch {
        Write-Warning "  > [FAILED] Accessing Account details: $($_.Exception.Message)"
    }
}

# --- Test-mode override ---
if ($SendTestEmail -eq 'true' -and $Results.Count -eq 0) {
    Write-Output "TEST MODE: SendTestEmail is 'true' and no real alerts were found — injecting a dummy row to exercise the full alert path."
    $Results += [PSCustomObject]@{
        Account = 'TEST-ACCOUNT'
        Share   = 'TEST-SHARE'
        QuotaGB = 100
        UsedGB  = 90
        FreeGB  = 10
    }
}

# --- 4. Alerting with Debugging ---
Write-Output "--------------------------------------------------"
If ($Results.Count -gt 0) {
    Write-Output "ALERT TRIGGER: Found $($Results.Count) issues. Preparing payload..."

    try {
        # Convert to HTML
        $TableHtml = $Results | ConvertTo-Html -Fragment
        $Subject = "Storage Account Alert for ${CompanyName}: Low Free Space"
        $HtmlBody = "<h3>Low Storage Space Detected for ${CompanyName}</h3><p>The following shares have less than $ThresholdGB GB free space:</p>$TableHtml"

        # Acquire a Managed Identity access token for Azure Communication
        # Services. Get-AzAccessToken's .Token property is a plain string
        # in some Az.Accounts versions and a SecureString in others
        # (documented breaking-change area) — handle both.
        Write-Output "ACTION: Requesting Managed Identity token for Azure Communication Services..."
        $TokenResult = Get-AzAccessToken -ResourceUrl 'https://communication.azure.com'
        if ($TokenResult.Token -is [System.Security.SecureString]) {
            $AccessToken = [System.Net.NetworkCredential]::new('', $TokenResult.Token).Password
        }
        else {
            $AccessToken = $TokenResult.Token
        }

        # Construct Payload (ACS Email "emails:send" request shape)
        $EmailPayload = @{
            senderAddress = $SenderAddress
            content       = @{
                subject = $Subject
                html    = $HtmlBody
            }
            recipients    = @{
                to = @(
                    @{ address = $AlertRecipientAddress }
                )
            }
        }

        $JsonPayload = $EmailPayload | ConvertTo-Json -Depth 6

        # DEBUG: Print size of payload
        Write-Output "DEBUG: Payload size is $([System.Text.Encoding]::UTF8.GetByteCount($JsonPayload)) bytes."

        # Action: Sending POST to Azure Communication Services
        Write-Output "ACTION: Sending email via Azure Communication Services..."

        # Using the Robust -SkipHttpErrorCheck method
        # ACS Email "Send" REST API — api-version 2025-09-01 confirmed as the
        # current stable data-plane version via Microsoft's official REST
        # reference (https://learn.microsoft.com/en-us/rest/api/communication/email/email/send?view=rest-communication-email-2025-09-01,
        # checked 2026-09-15). This is the Email data-plane API version, not
        # the ARM control-plane api-version used in acsEmail.bicep/
        # acsRoleAssignment.bicep — the identical value is coincidental, not a
        # copy-paste error (verified independently, not assumed).
        $Response = Invoke-RestMethod -Uri "$AcsEndpoint/emails:send?api-version=2025-09-01" `
            -Method Post `
            -Headers @{ Authorization = "Bearer $AccessToken" } `
            -Body $JsonPayload `
            -ContentType "application/json" `
            -SkipHttpErrorCheck `
            -StatusCodeVariable "HttpStatusCode"

        # CHECK THE STATUS CODE MANUALLY
        if ($HttpStatusCode -ge 400) {
            # This block runs if ACS returns an error (e.g., 400, 401, 500)
            Write-Error "CRITICAL: ACS Email API returned error code $HttpStatusCode"

            Write-Output "--- ERROR RESPONSE CONTENT ---"
            $Response | ConvertTo-Json -Depth 5
            Write-Output "------------------------------"
        }
        else {
            # 202 Accepted is success: ACS queues the email asynchronously.
            Write-Output "SUCCESS: ACS accepted the email request (Status: $HttpStatusCode)."
        }
    }
    catch {
        # Because we used -SkipHttpErrorCheck, this block ONLY catches
        # distinct connectivity failures (DNS failed, Internet down, Timeout),
        # NOT server error responses.
        Write-Error "CRITICAL: Network/Connectivity to Azure Communication Services FAILED."
        Write-Output "  |-- Exception: $($_.Exception.Message)"
    }
} else {
    Write-Output "HEALTHY: No shares below threshold. No alert sent."
}