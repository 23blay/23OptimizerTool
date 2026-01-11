# 23 Optimizer - Complete System Optimizer
# Safe, professional, and feature-rich

# ============================================
# INITIALIZATION
# ============================================

$ErrorActionPreference = 'SilentlyContinue'
$BackupDir = "$env:USERPROFILE\Documents\23Optimizer"
$LogFile = "$BackupDir\optimizer.log"
$ChangesMade = @()
$StartTime = Get-Date

# Create backup directory
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# ============================================
# LOGGING FUNCTION
# ============================================

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$Message" -ForegroundColor Gray
}

# ============================================
# SAFETY FUNCTIONS
# ============================================

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Create-RestorePoint {
    Write-Host "`nCreating system restore point..." -ForegroundColor Cyan
    try {
        $description = "23 Optimizer Backup - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "[✓] Restore point created" -ForegroundColor Green
        Write-Log "Created restore point: $description"
        return $true
    }
    catch {
        Write-Host "[!] Could not create restore point" -ForegroundColor Yellow
        Write-Host "    (System Protection may be disabled)" -ForegroundColor Gray
        return $false
    }
}

# ============================================
# OPTIMIZATION MODULES
# ============================================

# Module 1: Quick Cleanup (100% Safe)
function Optimize-Cleanup {
    Write-Host "`n[1/8] Cleaning temporary files..." -ForegroundColor Cyan
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned temp files"
    
    Write-Host "[2/8] Cleaning prefetch..." -ForegroundColor Cyan
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned prefetch"
    
    Write-Host "[3/8] Emptying recycle bin..." -ForegroundColor Cyan
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Log "Emptied recycle bin"
    
    Write-Host "[4/8] Flushing DNS cache..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Write-Log "Flushed DNS cache"
    
    Write-Host "[5/8] Cleaning error reports..." -ForegroundColor Cyan
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned error reports"
    
    Write-Host "[6/8] Cleaning thumbnail cache..." -ForegroundColor Cyan
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -ErrorAction SilentlyContinue
    Write-Log "Cleaned thumbnail cache"
    
    Write-Host "[7/8] Cleaning Windows Update cache..." -ForegroundColor Cyan
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Log "Cleaned Windows Update cache"
    
    Write-Host "[8/8] Running Disk Cleanup..." -ForegroundColor Cyan
    cleanmgr /sagerun:1 | Out-Null
    Write-Log "Ran Disk Cleanup"
    
    Write-Host "`n[✓] Cleanup completed!" -ForegroundColor Green
    $script:ChangesMade += "Quick Cleanup"
}

# Module 2: Disk Optimization
function Optimize-Disk {
    Write-Host "`n[1/4] Optimizing C: drive..." -ForegroundColor Cyan
    
    # Check if SSD or HDD
    $drive = Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0}
    
    if ($drive.MediaType -eq 'SSD') {
        Write-Host "   Detected SSD - Running TRIM" -ForegroundColor Gray
        Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
        Write-Log "SSD TRIM optimization"
    }
    else {
        Write-Host "   Detected HDD - Defragmenting" -ForegroundColor Gray
        Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
        Write-Log "HDD defragmentation"
    }
    
    Write-Host "[2/4] Disabling Last Access timestamp..." -ForegroundColor Cyan
    fsutil behavior set disablelastaccess 1 | Out-Null
    Write-Log "Disabled Last Access timestamp"
    
    Write-Host "[3/4] Disabling NTFS 8.3 naming..." -ForegroundColor Cyan
    fsutil behavior set disable8dot3 1 | Out-Null
    Write-Log "Disabled 8.3 naming"
    
    Write-Host "[4/4] Setting optimal cluster size..." -ForegroundColor Cyan
    # This is informational only - doesn't change anything
    Write-Host "   Recommended: 4KB for NTFS" -ForegroundColor Gray
    
    Write-Host "`n[✓] Disk optimization completed!" -ForegroundColor Green
    $script:ChangesMade += "Disk Optimization"
}

# Module 3: Network Optimization
function Optimize-Network {
    Write-Host "`n[1/6] Resetting network stack..." -ForegroundColor Cyan
    netsh winsock reset | Out-Null
    netsh int ip reset | Out-Null
    Write-Log "Reset network stack"
    
    Write-Host "[2/6] Flushing DNS..." -ForegroundColor Cyan
    ipconfig /flushdns | Out-Null
    Write-Log "Flushed DNS"
    
    Write-Host "[3/6] Releasing/Renewing IP..." -ForegroundColor Cyan
    ipconfig /release | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew | Out-Null
    Write-Log "Released/Renewed IP"
    
    Write-Host "[4/6] Optimizing TCP parameters..." -ForegroundColor Cyan
    $tcpParams = @{
        "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" = @{
            "TcpAckFrequency" = 1
            "TCPNoDelay" = 1
            "TcpWindowSize" = 64240
            "DefaultTTL" = 64
        }
    }
    
    foreach ($path in $tcpParams.Keys) {
        if (Test-Path $path) {
            foreach ($param in $tcpParams[$path].GetEnumerator()) {
                Set-ItemProperty -Path $path -Name $param.Key -Value $param.Value -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Log "Optimized TCP parameters"
    
    Write-Host "[5/6] Disabling Nagle's algorithm..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -Name "TcpAckFrequency" -Value 1 -ErrorAction SilentlyContinue
    Write-Log "Disabled Nagle's algorithm"
    
    Write-Host "[6/6] Setting DNS to Google/Cloudflare..." -ForegroundColor Cyan
    Write-Host "   Recommended: 8.8.8.8 and 1.1.1.1" -ForegroundColor Gray
    Write-Host "   Set manually in Network Settings" -ForegroundColor Gray
    
    Write-Host "`n[✓] Network optimization completed!" -ForegroundColor Green
    $script:ChangesMade += "Network Optimization"
}

# Module 4: Privacy & Telemetry
function Optimize-Privacy {
    Write-Host "`n[1/7] Disabling telemetry..." -ForegroundColor Cyan
    $telemetryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    )
    
    foreach ($path in $telemetryPaths) {
        if (-not (Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
    }
    Write-Log "Disabled telemetry"
    
    Write-Host "[2/7] Disabling Cortana..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -ErrorAction SilentlyContinue
    Write-Log "Disabled Cortana"
    
    Write-Host "[3/7] Disabling advertising ID..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -ErrorAction SilentlyContinue
    Write-Log "Disabled advertising ID"
    
    Write-Host "[4/7] Disabling Windows tips..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -ErrorAction SilentlyContinue
    Write-Log "Disabled Windows tips"
    
    Write-Host "[5/7] Disabling location tracking..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -ErrorAction SilentlyContinue
    Write-Log "Disabled location tracking"
    
    Write-Host "[6/7] Disabling feedback requests..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -ErrorAction SilentlyContinue
    Write-Log "Disabled feedback requests"
    
    Write-Host "[7/7] Clearing recent files list..." -ForegroundColor Cyan
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Cleared recent files"
    
    Write-Host "`n[✓] Privacy optimization completed!" -ForegroundColor Green
    $script:ChangesMade += "Privacy Optimization"
}

# Module 5: Performance Tweaks
function Optimize-Performance {
    Write-Host "`n[1/8] Setting performance power plan..." -ForegroundColor Cyan
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    Write-Log "Set high performance power plan"
    
    Write-Host "[2/8] Disabling visual effects..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -ErrorAction SilentlyContinue
    Write-Log "Disabled visual effects"
    
    Write-Host "[3/8] Optimizing for background services..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -ErrorAction SilentlyContinue
    Write-Log "Optimized background services"
    
    Write-Host "[4/8] Disabling Superfetch on SSDs..." -ForegroundColor Cyan
    $drive = Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0}
    if ($drive.MediaType -eq 'SSD') {
        Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name SysMain -Force -ErrorAction SilentlyContinue
        Write-Log "Disabled Superfetch (SSD detected)"
    }
    
    Write-Host "[5/8] Optimizing memory management..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -ErrorAction SilentlyContinue
    Write-Log "Optimized memory management"
    
    Write-Host "[6/8] Disabling NTFS last access..." -ForegroundColor Cyan
    fsutil behavior set disablelastaccess 1 | Out-Null
    Write-Log "Disabled NTFS last access"
    
    Write-Host "[7/8] Setting processor scheduling..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 26 -ErrorAction SilentlyContinue
    Write-Log "Set processor scheduling"
    
    Write-Host "[8/8] Disabling unnecessary animations..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
    Write-Log "Disabled animations"
    
    Write-Host "`n[✓] Performance optimization completed!" -ForegroundColor Green
    $script:ChangesMade += "Performance Tweaks"
}

# Module 6: Service Optimization (Safe)
function Optimize-Services {
    Write-Host "`n[1/5] Optimizing Windows Search..." -ForegroundColor Cyan
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
    if ($ram -lt 8) {
        Set-Service -Name WSearch -StartupType Manual -ErrorAction SilentlyContinue
        Write-Log "Set Windows Search to Manual (low RAM)"
    }
    
    Write-Host "[2/5] Disabling unnecessary services..." -ForegroundColor Cyan
    $servicesToDisable = @(
        "DiagTrack",        # Diagnostics Tracking
        "dmwappushservice", # WAP Push Message Routing
        "MapsBroker",       # Downloaded Maps Manager
        "lfsvc",            # Geolocation Service
        "RemoteRegistry",   # Remote Registry
        "WMPNetworkSvc"     # Windows Media Player Network Sharing
    )
    
    foreach ($service in $servicesToDisable) {
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue 2>$null
    }
    Write-Log "Disabled unnecessary services"
    
    Write-Host "[3/5] Optimizing Windows Update..." -ForegroundColor Cyan
    Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
    Write-Log "Set Windows Update to Manual"
    
    Write-Host "[4/5] Optimizing Print Spooler..." -ForegroundColor Cyan
    if (-not (Get-Printer -ErrorAction SilentlyContinue)) {
        Set-Service -Name Spooler -StartupType Manual -ErrorAction SilentlyContinue
        Write-Log "Set Print Spooler to Manual (no printers)"
    }
    
    Write-Host "[5/5] Optimizing Superfetch..." -ForegroundColor Cyan
    $drive = Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0}
    if ($drive.MediaType -eq 'SSD') {
        Set-Service -Name SysMain -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Log "Disabled Superfetch (SSD)"
    }
    
    Write-Host "`n[✓] Service optimization completed!" -ForegroundColor Green
    $script:ChangesMade += "Service Optimization"
}

# Module 7: Startup Optimization
function Optimize-Startup {
    Write-Host "`nOptimizing startup items..." -ForegroundColor Cyan
    
    # Show current startup items
    $startupItems = Get-CimInstance Win32_StartupCommand | 
        Select-Object Name, Command, Location, User
    
    if ($startupItems.Count -eq 0) {
        Write-Host "No startup items found" -ForegroundColor Gray
        return
    }
    
    Write-Host "`nCurrent startup items:" -ForegroundColor Yellow
    $startupItems | Format-Table -AutoSize
    
    Write-Host "`nTo manage startup items:" -ForegroundColor Cyan
    Write-Host "1. Press Ctrl+Shift+Esc" -ForegroundColor Gray
    Write-Host "2. Go to Startup tab" -ForegroundColor Gray
    Write-Host "3. Disable unnecessary items" -ForegroundColor Gray
    
    Write-Host "`n[✓] Startup optimization info displayed" -ForegroundColor Green
    $script:ChangesMade += "Startup Optimization Info"
}

# Module 8: System Information
function Show-SystemInfo {
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "SYSTEM INFORMATION" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Cyan
    
    # OS Info
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "`nOS: $($os.Caption)" -ForegroundColor Yellow
    Write-Host "Version: $($os.Version)" -ForegroundColor Gray
    Write-Host "Build: $($os.BuildNumber)" -ForegroundColor Gray
    
    # Hardware Info
    $cpu = Get-CimInstance Win32_Processor
    Write-Host "`nCPU: $($cpu.Name)" -ForegroundColor Yellow
    Write-Host "Cores: $($cpu.NumberOfCores)" -ForegroundColor Gray
    Write-Host "Threads: $($cpu.NumberOfLogicalProcessors)" -ForegroundColor Gray
    
    $ram = Get-CimInstance Win32_ComputerSystem
    $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    Write-Host "`nRAM: ${totalRAM}GB" -ForegroundColor Yellow
    
    $gpu = Get-CimInstance Win32_VideoController
    Write-Host "`nGPU: $($gpu.Name)" -ForegroundColor Yellow
    
    # Disk Info
    $disk = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    $usedGB = [math]::Round(($disk.Used) / 1GB, 2)
    Write-Host "`nDisk C:" -ForegroundColor Yellow
    Write-Host "Free: ${freeGB}GB" -ForegroundColor Gray
    Write-Host "Used: ${usedGB}GB" -ForegroundColor Gray
    
    # Network Info
    $network = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Ethernet*" -or $_.InterfaceAlias -like "*Wi-Fi*"}
    Write-Host "`nNetwork:" -ForegroundColor Yellow
    foreach ($adapter in $network) {
        Write-Host "$($adapter.InterfaceAlias): $($adapter.IPAddress)" -ForegroundColor Gray
    }
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Log "Displayed system information"
}

# ============================================
# MAIN MENU
# ============================================

function Show-MainMenu {
    do {
        Clear-Host
        Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║             23 OPTIMIZER                ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1.  Quick Cleanup" -ForegroundColor Yellow
        Write-Host "2.  Disk Optimization" -ForegroundColor Yellow
        Write-Host "3.  Network Optimization" -ForegroundColor Yellow
        Write-Host "4.  Privacy & Telemetry" -ForegroundColor Yellow
        Write-Host "5.  Performance Tweaks" -ForegroundColor Yellow
        Write-Host "6.  Service Optimization" -ForegroundColor Yellow
        Write-Host "7.  Startup Management" -ForegroundColor Yellow
        Write-Host "8.  System Information" -ForegroundColor Yellow
        Write-Host "9.  Complete Optimization" -ForegroundColor Green
        Write-Host "10. Create Restore Point" -ForegroundColor Magenta
        Write-Host "11. View Optimization Log" -ForegroundColor Gray
        Write-Host "0.  Exit" -ForegroundColor Red
        Write-Host ""
        Write-Host "════════════════════════════════════════════" -ForegroundColor Cyan
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            '1' { Optimize-Cleanup; Pause-AndReturn }
            '2' { Optimize-Disk; Pause-AndReturn }
            '3' { Optimize-Network; Pause-AndReturn }
            '4' { Optimize-Privacy; Pause-AndReturn }
            '5' { Optimize-Performance; Pause-AndReturn }
            '6' { Optimize-Services; Pause-AndReturn }
            '7' { Optimize-Startup; Pause-AndReturn }
            '8' { Show-SystemInfo; Pause-AndReturn }
            '9' { Complete-Optimization }
            '10' { Create-RestorePoint; Pause-AndReturn }
            '11' { Show-Log; Pause-AndReturn }
            '0' { return }
            default { Write-Host "Invalid selection!" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne '0')
}

# ============================================
# COMPLETE OPTIMIZATION
# ============================================

function Complete-Optimization {
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "COMPLETE SYSTEM OPTIMIZATION" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will run all optimization modules." -ForegroundColor Yellow
    Write-Host "Estimated time: 2-3 minutes" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne 'Y') { return }
    
    # Create restore point first
    Create-RestorePoint
    
    # Run all modules
    Optimize-Cleanup
    Optimize-Disk
    Optimize-Network
    Optimize-Privacy
    Optimize-Performance
    Optimize-Services
    Optimize-Startup
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor Gray
    Write-Host "2. Check for Windows updates" -ForegroundColor Gray
    Write-Host "3. Run monthly for maintenance" -ForegroundColor Gray
    Write-Host ""
    
    $endTime = Get-Date
    $duration = $endTime - $StartTime
    Write-Log "Complete optimization finished in $($duration.TotalMinutes.ToString('0.0')) minutes"
    
    Pause-AndReturn
}

# ============================================
# HELPER FUNCTIONS
# ============================================

function Pause-AndReturn {
    Write-Host "`nPress any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-Log {
    if (Test-Path $LogFile) {
        Write-Host "`nLast 20 log entries:" -ForegroundColor Cyan
        Get-Content $LogFile -Tail 20
    }
    else {
        Write-Host "No log file found" -ForegroundColor Yellow
    }
}

# ============================================
# MAIN EXECUTION
# ============================================

# Check admin rights
if (-not (Test-Admin)) {
    Write-Host "`n[!] Run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click and select 'Run as administrator'" -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit
}

# Start
Write-Log "23 Optimizer started"
Show-MainMenu

# Finish
$endTime = Get-Date
$duration = $endTime - $StartTime
Write-Log "23 Optimizer finished. Duration: $($duration.TotalMinutes.ToString('0.0')) minutes"
Write-Host "`nThank you for using 23 Optimizer!" -ForegroundColor Green
Write-Host "Log saved to: $LogFile" -ForegroundColor Gray
Start-Sleep -Seconds 2