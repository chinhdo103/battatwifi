# Đường dẫn tới thư mục script
$scriptDirectory = $PSScriptRoot
$offScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOffWiFi.ps1"
$onScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOnWiFi.ps1"

# Kiểm tra quyền Admin
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $runAsAdmin.IsInRole($adminRole)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File $PSCommandPath" -Verb runAs
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

	
# Hàm hiển thị menu
function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " QUAN LY HEN GIO TAT WIFI " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "1. Nhap gio hen tat Wi-Fi va tu dong bat lai khi khoi dong hoac dang nhap"
    Write-Host "2. Xoa tat ca gio da hen"
    Write-Host "0. Thoat chuong trinh"
    Write-Host "============================================" -ForegroundColor Cyan
}

# Hàm chỉnh sửa điều kiện AC Power
function Remove-ACPowerCondition {
    param (
        [string]$taskName
    )
    $taskXml = schtasks /Query /TN $taskName /XML | Out-String
    $taskXml = $taskXml -replace '<DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>', '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>'
    $tempFile = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tempFile -Value $taskXml
    schtasks /Create /TN $taskName /XML $tempFile /F
    Remove-Item $tempFile
}

# Hàm thêm giờ tắt Wi-Fi và tự bật khi khởi động hoặc đăng nhập
function Schedule-TurnOffWiFi {
    $hourOff = Read-Host "Nhap gio tat Wi-Fi (hh:mm, VD: 23:00)"
    if (-not ($hourOff -match "^\d{1,2}:\d{2}$")) {
        Write-Host "Thoi gian nhap khong hop le. Vui long nhap theo dinh dang hh:mm." -ForegroundColor Red
        return
    }

    $currentTime = Get-Date
    $offTime = [datetime]::ParseExact($hourOff, "HH:mm", $null)

    if ($offTime -lt $currentTime) {
        $offTime = $offTime.AddDays(1)
    }

    $formattedOffTime = $offTime.ToString("HH:mm")

    # Tạo tác vụ tắt Wi-Fi
    schtasks /Create `
        /TN "TurnOffWiFi" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$offScript'" `
        /SC DAILY /ST $formattedOffTime `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    Remove-ACPowerCondition -taskName "TurnOffWiFi"

    Write-Host "Da them gio hen tat Wi-Fi: $formattedOffTime thanh cong." -ForegroundColor Green

    # Tạo tác vụ bật Wi-Fi khi khởi động hoặc đăng nhập
    schtasks /Create `
        /TN "TurnOnWiFiAtLogon" `
        /TR "powershell.exe -ExecutionPolicy Bypass -File '$onScript'" `
        /SC ONLOGON `
        /F /RL HIGHEST /RU "SYSTEM" `
        /IT

    Write-Host "Tac vu tu dong bat Wi-Fi khi khoi dong hoac dang nhap da duoc tao." -ForegroundColor Green
}

# Hàm xóa tất cả tác vụ đã hẹn
function Remove-ScheduledTimes {
    schtasks /Delete /TN "TurnOffWiFi" /F > $null
    schtasks /Delete /TN "TurnOnWiFiAtLogon" /F > $null
    Write-Host "Da xoa tat ca gio hen thanh cong." -ForegroundColor Green
    Pause
}

# Chương trình chính
do {
    Show-Menu
    $choice = Read-Host "Vui long chon (0-2)"
    switch ($choice) {
        "1" { Schedule-TurnOffWiFi }
        "2" { Remove-ScheduledTimes }
        "0" { Write-Host "Thoat chuong trinh. Tam biet!" -ForegroundColor Yellow; Exit }
        default { Write-Host "Lua chon khong hop le. Vui long thu lai!" -ForegroundColor Red }
    }
} while ($true)