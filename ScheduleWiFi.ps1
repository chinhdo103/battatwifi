
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $runAsAdmin.IsInRole($adminRole)) {
    # Nếu không có quyền admin, yêu cầu chạy lại với quyền admin
    $arguments = [Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $arguments -Verb runAs
    Exit
}
# Hàm kiểm tra đăng nhập
function Check-Login {
    $username = Read-Host "Nhap tai khoan "
    $password = Read-Host "Nhap mat khau" -AsSecureString

    # Tạo mật khẩu string từ SecureString để kiểm tra
    $passwordUnsecured = [System.Net.NetworkCredential]::new("", $password).Password

    # Kiểm tra tài khoản và mật khẩu
    if ($username -eq "admin" -and $passwordUnsecured -eq "xuanthanh") {
        Write-Host "Dang nhap thanh cong!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Sai tai khoan hoac mat khau. Vui long thu lai." -ForegroundColor Red
        return $false
    }
}

# Kiểm tra đăng nhập trước khi cho phép truy cập các chức năng
if (-not (Check-Login)) {
    Write-Host "Chuong trinh ket thuc!" -ForegroundColor Red
    Exit
}
# Hàm hiển thị menu
function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " QUAN LY HEN GIO BAT/TAT WIFI " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "1. Nhap gio hen tat va bat Wi-Fi"
    Write-Host "2. Hien thi gio da hen"
    Write-Host "3. Xoa tat ca gio da hen"
    Write-Host "4. Bat wifi thu cong"
    Write-Host "0. Thoat"
    Write-Host "============================================" -ForegroundColor Cyan
}

# Lấy đường dẫn của thư mục chứa file gốc
$scriptDirectory = $PSScriptRoot

# Đường dẫn đầy đủ tới các tệp TurnOffWiFi.ps1 và TurnOnWiFi.ps1
$offScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOffWiFi.ps1"
$onScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOnWiFi.ps1"
# Hàm chỉnh sửa điều kiện "Start the task only if the computer is on AC power"
function Remove-ACPowerCondition {
    param (
        [string]$taskName
    )
    # Lấy XML của tác vụ từ Task Scheduler
    $taskXml = schtasks /Query /TN $taskName /XML | Out-String

    # Chỉnh sửa XML để loại bỏ điều kiện "Start the task only if the computer is on AC power"
    $taskXml = $taskXml -replace '<StartWhenAvailable>true</StartWhenAvailable>', '<StartWhenAvailable>false</StartWhenAvailable>'
    $taskXml = $taskXml -replace '<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
    $taskXml = $taskXml -replace '<StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>', '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>'

    # Lưu lại tác vụ với thay đổi
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $taskXml
    schtasks /Create /TN $taskName /XML $tempFile /F
    Remove-Item $tempFile
}

# Sau khi tạo tác vụ, gọi hàm để chỉnh sửa điều kiện
Remove-ACPowerCondition -taskName "TurnOffWiFi"
Remove-ACPowerCondition -taskName "TurnOnWiFi"

# Hàm thêm giờ tắt và bật Wi-Fi
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

    # Tạo chuỗi thời gian đúng định dạng
    $formattedOffTime = $offTime.ToString("HH:mm")
    $formattedOnTime = $onTime.ToString("HH:mm")


    $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -ne "Disconnected" }
    if (-not $wifiAdapter) {
        Write-Host "Khong tim thay adapter Wi-Fi. Vui long kiem tra lai." -ForegroundColor Red
        return
    }

    # Tạo tác vụ tắt Wi-Fi với quyền admin
    schtasks /Create `
        /TN "TurnOffWiFi" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$offScript'" `
        /SC DAILY /ST $formattedOffTime `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    # Tạo tác vụ bật Wi-Fi
    schtasks /Create `
        /TN "TurnOnWiFi" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$onScript'" `
        /SC DAILY /ST $formattedOnTime `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    # Loại bỏ điều kiện AC power sau khi tạo tác vụ
    Remove-ACPowerCondition -taskName "TurnOffWiFi"
    Remove-ACPowerCondition -taskName "TurnOnWiFi"

    Write-Host "Da them gio hen tat: $formattedOffTime va bat: $formattedOnTime thanh cong." -ForegroundColor Green
}


# Hàm hiển thị giờ đã hẹn
function Show-ScheduledTimes {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " CAC GIO DA HEN " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan

    $tasks = schtasks /Query /FO LIST | Select-String "TurnOnWiFi|TurnOffWiFi"
    if ($tasks -ne $null) {
        $tasks | ForEach-Object {
            Write-Host $_.Line -ForegroundColor Green
        }
    } else {
        Write-Host "Khong co gio hen nao duoc tim thay." -ForegroundColor Red
    }
    Pause
}
# Hàm hiển thị giờ đã hẹn
function batwifi {
     Clear-Host

# Tìm adapter Wi-Fi và bật nó
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -eq "Disabled" }

if ($wifiAdapter) {
    Enable-NetAdapter -Name $wifiAdapter.Name -Confirm:$false
    Write-Host "Wi-Fi đã được bật." -ForegroundColor Green
} else {
    Write-Host "Không tìm thấy adapter Wi-Fi hoặc nó đã được bật." -ForegroundColor Red
}

}

# Hàm xóa tất cả giờ đã hẹn
function Remove-ScheduledTimes {
    schtasks /Delete /TN "TurnOffWiFi" /F > $null
    schtasks /Delete /TN "TurnOnWiFi" /F > $null
    Write-Host "Da xoa tat ca gio hen thanh cong." -ForegroundColor Green
}

# Chương trình chính
do {
    Show-Menu
    $choice = Read-Host "Vui long chon (0-4)"
    switch ($choice) {
        "1" { Schedule-WiFi }
        "2" { Show-ScheduledTimes }
        "3" { Remove-ScheduledTimes }
        "4" { batwifi}
        "0" { Write-Host "Thoat chuong trinh. Tam biet!" -ForegroundColor Yellow; break }
        default { Write-Host "Lua chon khong hop le. Vui long thu lai!" -ForegroundColor Red }
    }
} while ($true)
