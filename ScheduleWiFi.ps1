# Chuong trinh PowerShell quan ly hen gio bat/tat Wi-Fi
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $runAsAdmin.IsInRole($adminRole)) {
    # Neu khong co quyen admin, yeu cau chay lai voi quyen admin
    $arguments = [Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $arguments -Verb runAs
    Exit
}

# Ham kiem tra dang nhap
function Check-Login {
    $username = Read-Host "Nhap tai khoan"
    $password = Read-Host "Nhap mat khau" -AsSecureString

    # Tao mat khau string tu SecureString de kiem tra
    $passwordUnsecured = [System.Net.NetworkCredential]::new("", $password).Password

    # Kiem tra tai khoan va mat khau
    if ($username -eq "admin" -and $passwordUnsecured -eq "xuanthanh") {
        Write-Host "Dang nhap thanh cong!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Sai tai khoan hoac mat khau. Vui long thu lai." -ForegroundColor Red
        return $false
    }
}

# Kiem tra dang nhap truoc khi cho phep truy cap cac chuc nang
if (-not (Check-Login)) {
    Write-Host "Chuong trinh ket thuc!" -ForegroundColor Red
    Exit
}

# Ham hien thi menu
function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " QUAN LY HEN GIO BAT/TAT WIFI " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "1. Nhap gio hen tat va bat Wi-Fi (dinh dang 24h: hh:mm)"
    Write-Host "2. Hien thi ten cac file da hen"
    Write-Host "3. Xoa tat ca gio da hen"
    Write-Host "4. Bat Wi-Fi thu cong"
    Write-Host "0. Thoat chuong trinh"
    Write-Host "============================================" -ForegroundColor Cyan
}

# Lay duong dan cua thu muc chua file goc
$scriptDirectory = $PSScriptRoot

# Duong dan day du toi cac tep TurnOffWiFi.ps1 va TurnOnWiFi.ps1
$offScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOffWiFi.ps1"
$onScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOnWiFi.ps1"

# Ham chinh sua dieu kien "Start the task only if the computer is on AC power"
function Remove-ACPowerCondition {
    param (
        [string]$taskName
    )
    $taskXml = schtasks /Query /TN $taskName /XML | Out-String

    $taskXml = $taskXml -replace '<StartWhenAvailable>true</StartWhenAvailable>', '<StartWhenAvailable>false</StartWhenAvailable>'
    $taskXml = $taskXml -replace '<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
    $taskXml = $taskXml -replace '<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>', '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'

    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $taskXml
    schtasks /Create /TN $taskName /XML $tempFile /F
    Remove-Item $tempFile
}

# Ham them gio tat va bat Wi-Fi
function Schedule-WiFi {
    $hourOff = Read-Host "Nhap gio tat Wi-Fi (hh:mm, VD: 23:00)"
    $hourOn = Read-Host "Nhap gio bat Wi-Fi (hh:mm, VD: 06:00)"

    if (-not ($hourOff -match "^\d{1,2}:\d{2}$" -and $hourOn -match "^\d{1,2}:\d{2}$")) {
        Write-Host "Thoi gian nhap khong hop le. Vui long nhap theo dinh dang hh:mm." -ForegroundColor Red
        return
    }

    $currentTime = Get-Date
    $offTime = [datetime]::ParseExact($hourOff, "HH:mm", $null)
    $onTime = [datetime]::ParseExact($hourOn, "HH:mm", $null)

    if ($offTime -lt $currentTime) {
        $offTime = $offTime.AddDays(1)
    }

    if ($onTime -lt $currentTime) {
        $onTime = $onTime.AddDays(1)
    }

    if ($onTime -lt $offTime) {
        $onTime = $onTime.AddDays(1)
    }

    $formattedOffTime = $offTime.ToString("HH:mm")
    $formattedOnTime = $onTime.ToString("HH:mm")

    schtasks /Create `
        /TN "TurnOffWiFi" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$offScript'" `
        /SC DAILY /ST $formattedOffTime `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    schtasks /Create `
        /TN "TurnOnWiFi" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$onScript'" `
        /SC DAILY /ST $formattedOnTime `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    Remove-ACPowerCondition -taskName "TurnOffWiFi"
    Remove-ACPowerCondition -taskName "TurnOnWiFi"

    Write-Host "Da them gio hen tat: $formattedOffTime va bat: $formattedOnTime thanh cong." -ForegroundColor Green
}

# Ham hien thi ten file da hen
function Show-ScheduledTimes {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " CAC FILE DA HEN " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan

    $tasks = schtasks /Query /FO LIST | Select-String "TurnOnWiFi|TurnOffWiFi"
    if ($tasks -ne $null) {
        Write-Host "Ban da hen gio"
       
    } else {
        Write-Host "Khong co gio hen nao duoc tim thay." -ForegroundColor Red
    }
    Pause
}

# Ham bat Wi-Fi thu cong
function BatWiFi {
    $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -eq "Disabled" }
    if ($wifiAdapter) {
        Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
        Write-Host "Wi-Fi da duoc bat." -ForegroundColor Green
    } else {
        Write-Host "Khong tim thay adapter Wi-Fi hoac no da duoc bat." -ForegroundColor Red
    }
}

# Ham xoa tat ca gio da hen
function Remove-ScheduledTimes {
    schtasks /Delete /TN "TurnOffWiFi" /F > $null
    schtasks /Delete /TN "TurnOnWiFi" /F > $null
    Write-Host "Da xoa tat ca gio hen thanh cong." -ForegroundColor Green
    Pause
}

# Chuong trinh chinh
do {
    Show-Menu
    $choice = Read-Host "Vui long chon (0-4)"
    switch ($choice) {
        "1" { Schedule-WiFi }
        "2" { Show-ScheduledTimes }
        "3" { Remove-ScheduledTimes }
        "4" { BatWiFi }
        "0" { Write-Host "Thoat chuong trinh. Tam biet!" -ForegroundColor Yellow; Exit }
        default { Write-Host "Lua chon khong hop le. Vui long thu lai!" -ForegroundColor Red }
    }
} while ($true)
