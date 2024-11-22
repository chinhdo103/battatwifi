$logFile = "C:\Path\To\Your\Log\wifi_log.txt"
Add-Content -Path $logFile -Value "$(Get-Date) - TurnOffWiFi started."

# Kiểm tra adapter Wi-Fi
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -ne "Disconnected" }

if ($wifiAdapter) {
    Add-Content -Path $logFile -Value "$(Get-Date) - Wi-Fi adapter found: $($wifiAdapter.Name). Disabling..."
    Disable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
    Add-Content -Path $logFile -Value "$(Get-Date) - Wi-Fi disabled."
} else {
    Add-Content -Path $logFile -Value "$(Get-Date) - No Wi-Fi adapter found."
}
