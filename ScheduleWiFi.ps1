# Kiểm tra quyền quản trị (admin)
$runAsAdmin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $runAsAdmin.IsInRole($adminRole)) {
    # Nếu không có quyền admin, yêu cầu chạy lại với quyền admin
    $arguments = [Environment]::GetCommandLineArgs()
    Start-Process powershell -ArgumentList $arguments -Verb runAs
    Exit
}

# Nếu đã có quyền admin, tiếp tục chạy script
Write-Host "Script đang chạy với quyền admin!" -ForegroundColor Green

# Đăng nhập
$validUser = $false
$maxAttempts = 3
$attempt = 0
$userName = "admin"
$password = "xuanthanh"

do {
    $userInput = Read-Host "Nhap tai khoan"
    $passInput = Read-Host "Nhap mat khau" -AsSecureString
    $unsecurePass = [System.Net.NetworkCredential]::new("", $passInput).Password
    
    if ($userInput -eq $userName -and $unsecurePass -eq $password) {
        Write-Host "Dang nhap thanh cong!" -ForegroundColor Green
        $validUser = $true
    } else {
        $attempt++
        Write-Host "Tai khoan hoac mat khau khong dung. Vui long thu lai!" -ForegroundColor Red
        if ($attempt -ge $maxAttempts) {
            Write-Host "Ban da nhap sai qua so lan quy dinh. Khoa chuc nang!" -ForegroundColor Red
            Exit
        }
    }
} while (-not $validUser)

# Hàm hiển thị menu với giao diện đẹp hơn
function Show-Menu {
    Clear-Host
    $menuTitle = "============================================"
    $header = "QUAN LY HEN GIO BAT/TAT WIFI"
    
    # In tiêu đề căn giữa với màu sắc nổi bật
    Write-Host ($menuTitle.PadLeft(($menuTitle.Length + $header.Length) / 2)) -ForegroundColor Cyan
    Write-Host $header.PadLeft(($menuTitle.Length + $header.Length) / 2) -ForegroundColor Yellow
    Write-Host ($menuTitle.PadLeft(($menuTitle.Length + $header.Length) / 2)) -ForegroundColor Cyan

    # In các lựa chọn với màu sắc
    Write-Host "1. Nhap gio hen tat va bat Wi-Fi" -ForegroundColor Green
    Write-Host "2. Hien thi gio da hen" -ForegroundColor Green
    Write-Host "3. Xoa tat ca gio da hen" -ForegroundColor Green
    Write-Host "0. Thoat" -ForegroundColor Red
    Write-Host ($menuTitle.PadLeft(($menuTitle.Length + $header.Length) / 2)) -ForegroundColor Cyan
}

# Lấy đường dẫn của thư mục chứa file gốc
$scriptDirectory = $PSScriptRoot

# Đường dẫn đầy đủ tới các tệp TurnOffWiFi.ps1 và TurnOnWiFi.ps1
$offScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOffWiFi.ps1"
$onScript = Join-Path -Path $scriptDirectory -ChildPath "TurnOnWiFi.ps1"

# Hàm thêm giờ tắt và bật Wi-Fi
function Schedule-WiFi {
    $hourOff = Read-Host "Nhap gio tat Wi-Fi (hh:mm, VD: 23:00)"
    $hourOn = Read-Host "Nhap gio bat Wi-Fi (hh:mm, VD: 06:00)"

    if (-not ($hourOff -match "^\d{1,2}:\d{2}$" -and $hourOn -match "^\d{1,2}:\d{2}$")) {
        Write-Host "Thoi gian nhap khong hop le. Vui long nhap theo dinh dang hh:mm." -ForegroundColor Red
        return
    }

    $wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Wi-Fi*" -and $_.Status -ne "Disconnected" }
    if (-not $wifiAdapter) {
        Write-Host "Khong tim thay adapter Wi-Fi. Vui long kiem tra lai." -ForegroundColor Red
        return
    }

    # Tạo tác vụ tắt Wi-Fi với quyền admin
    schtasks /Create /TN "TurnOffWiFi" /TR "powershell.exe -ExecutionPolicy Bypass -File '$offScript'" /SC DAILY /ST $hourOff /F /RL HIGHEST /RU "SYSTEM"
    # Tạo tác vụ bật Wi-Fi với quyền admin
    schtasks /Create /TN "TurnOnWiFi" /TR "powershell.exe -ExecutionPolicy Bypass -File '$onScript'" /SC DAILY /ST $hourOn /F /RL HIGHEST /RU "SYSTEM"

    Write-Host "Da them gio hen tat: $hourOff va bat: $hourOn thanh cong." -ForegroundColor Green
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

# Hàm xóa tất cả giờ đã hẹn
function Remove-ScheduledTimes {
    schtasks /Delete /TN "TurnOffWiFi" /F > $null
    schtasks /Delete /TN "TurnOnWiFi" /F > $null
    Write-Host "Da xoa tat ca gio hen thanh cong." -ForegroundColor Green
}

# Chương trình chính
do {
    Show-Menu
    $choice = Read-Host "Vui long chon (0-3)"
    switch ($choice) {
        "1" { Schedule-WiFi }
        "2" { Show-ScheduledTimes }
        "3" { Remove-ScheduledTimes }
        "0" { Write-Host "Thoat chuong trinh. Tam biet!" -ForegroundColor Yellow; break }
        default { Write-Host "Lua chon khong hop le. Vui long thu lai!" -ForegroundColor Red }
    }
} while ($true)
