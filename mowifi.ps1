# Kiểm tra quyền admin
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $runAsAdmin.IsInRole($adminRole)) {
    # Nếu không có quyền admin, yêu cầu chạy lại với quyền admin
    $arguments = [Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $arguments -Verb runAs
    Exit
}

# Nếu đã có quyền admin, tiếp tục bật Wi-Fi
Write-Host "Script đang chạy với quyền admin!" -ForegroundColor Green

# Tìm adapter Wi-Fi và bật nó
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -eq "Disabled" }

if ($wifiAdapter) {
    Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
    Write-Host "Wi-Fi đã được bật." -ForegroundColor Green
} else {
    Write-Host "Không tìm thấy adapter Wi-Fi hoặc nó đã được bật." -ForegroundColor Red
}
