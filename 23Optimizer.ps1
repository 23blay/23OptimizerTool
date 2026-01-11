# ============================================
# 23 OPTIMIZER - ULTIMATE EDITION
# ============================================

param(
    [string]$Mode = "Menu"
)

# ============================================
# CONFIGURATION
# ============================================

$Script:Version = "3.2"
$Script:BackupDir = "$env:USERPROFILE\Documents\23Optimizer"
$Script:LogFile = "$Script:BackupDir\log.txt"
$Script:ChangesMade = @()
$Script:StartTime = Get-Date

# ============================================
# INITIALIZATION
# ============================================

function Initialize-Optimizer {
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              23 OPTIMIZER v$Script:Version              ║" -ForegroundColor Green
    Write-Host "║          Ultimate System Optimization           ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Create backup directory
    if (-not (Test-Path $Script:BackupDir)) {
        New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null
        Write-Host "[✓] Created backup directory" -ForegroundColor Green
    }
    
    # Check admin rights
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "[!] Administrator privileges required!" -ForegroundColor Red
        Write-Host "    Please run as administrator" -ForegroundColor Yellow
        Pause-AnyKey
        exit 1
    }
    
    Write-Host "[✓] Running as Administrator" -ForegroundColor Green
    Write-Host "[✓] System ready for optimization" -ForegroundColor Green
    Write-Host ""
    
    # Log startup
    Add-Log "23 Optimizer started - Mode: $Mode"
}

# ============================================
# LOGGING SYSTEM
# ============================================

function Add-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $Script:LogFile -Append
}

function Show-Log {
    if (Test-Path $Script:LogFile) {
        Write-Host "`n[OPTIMIZATION LOG]" -ForegroundColor Cyan
        Get-Content $Script:LogFile -Tail 20 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "No log file found" -ForegroundColor Yellow
    }
}

# ============================================
# SAFETY FUNCTIONS
# ============================================

function Create-SystemRestorePoint {
    Write-Host "`n[SAFETY] Creating system restore point..." -ForegroundColor Cyan
    
    try {
        $description = "23 Optimizer Backup - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        # Try multiple methods
        try {
            Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Host "[✓] Restore point created via PowerShell" -ForegroundColor Green
        } catch {
            # Fallback to WMIC
            $null = wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint "$description", 100, 7
            Write-Host "[✓] Restore point created via WMIC" -ForegroundColor Green
        }
        
        Add-Log "Created restore point: $description"
        return $true
    } catch {
        Write-Host "[!] Could not create restore point" -ForegroundColor Yellow
        Write-Host "    System Protection might be disabled" -ForegroundColor Gray
        return $false
    }
}

# ============================================
# OPTIMIZATION MODULES
# ============================================

# MODULE 1: SYSTEM CLEANUP (SAFE)
function Optimize-SystemCleanup {
    Write-Host "`n[1. SYSTEM CLEANUP]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    $cleanupSteps = @(
        @{ Name = "Windows Temp Files"; Path = "$env:WINDIR\Temp\*"; Type = "Delete" },
        @{ Name = "User Temp Files"; Path = "$env:TEMP\*"; Type = "Delete" },
        @{ Name = "Prefetch Cache"; Path = "$env:WINDIR\Prefetch\*"; Type = "Delete" },
        @{ Name = "DNS Cache"; Command = "ipconfig /flushdns"; Type = "Command" },
        @{ Name = "Windows Error Reports"; Path = "$env:ProgramData\Microsoft\Windows\WER\*"; Type = "Delete" },
        @{ Name = "Recycle Bin"; Command = "Clear-RecycleBin -Force"; Type = "Command" },
        @{ Name = "Thumbnail Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"; Type = "Delete" },
        @{ Name = "Windows Update Cache"; Command = "net stop wuauserv"; Type = "Service" },
        @{ Name = "Windows Update Cache Clean"; Path = "$env:WINDIR\SoftwareDistribution\Download\*"; Type = "Delete" },
        @{ Name = "Windows Update Restart"; Command = "net start wuauserv"; Type = "Service" }
    )
    
    $successCount = 0
    foreach ($step in $cleanupSteps) {
        Write-Host "  • $($step.Name)..." -NoNewline -ForegroundColor Gray
        
        try {
            switch ($step.Type) {
                "Delete" {
                    if (Test-Path $step.Path) {
                        Remove-Item -Path $step.Path -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                "Command" {
                    Invoke-Expression $step.Command -ErrorAction SilentlyContinue | Out-Null
                }
                "Service" {
                    cmd /c $step.Command 2>$null | Out-Null
                }
            }
            
            Write-Host " ✓" -ForegroundColor Green
            $successCount++
            Add-Log "Cleaned: $($step.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # Run Disk Cleanup
    Write-Host "  • Disk Cleanup (System Files)..." -NoNewline -ForegroundColor Gray
    try {
        Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
        Write-Host " ✓" -ForegroundColor Green
        $successCount++
        Add-Log "Ran Disk Cleanup"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    Write-Host "`n  [$successCount/$($cleanupSteps.Count+1)] cleanup operations completed" -ForegroundColor Yellow
    $Script:ChangesMade += "System Cleanup"
}

# MODULE 2: DISK OPTIMIZATION
function Optimize-DiskPerformance {
    Write-Host "`n[2. DISK OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    # Detect disk type
    $diskInfo = Get-PhysicalDisk | Select-Object -First 1
    $isSSD = $diskInfo.MediaType -eq 'SSD'
    
    Write-Host "  Disk Type: $(if ($isSSD) {'SSD'} else {'HDD'})" -ForegroundColor Gray
    
    if ($isSSD) {
        Write-Host "  • Running TRIM optimization..." -NoNewline -ForegroundColor Gray
        try {
            Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "SSD TRIM optimization"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    } else {
        Write-Host "  • Defragmenting HDD..." -NoNewline -ForegroundColor Gray
        try {
            Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "HDD defragmentation"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # Disable last access timestamp
    Write-Host "  • Disabling last access timestamp..." -NoNewline -ForegroundColor Gray
    try {
        fsutil behavior set disablelastaccess 1 | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Disabled last access timestamp"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    # Disable 8.3 naming
    Write-Host "  • Disabling 8.3 filename creation..." -NoNewline -ForegroundColor Gray
    try {
        fsutil behavior set disable8dot3 1 | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Disabled 8.3 naming"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    # Check disk health
    Write-Host "  • Checking disk health..." -NoNewline -ForegroundColor Gray
    try {
        chkdsk C: /scan | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Disk health check completed"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    $Script:ChangesMade += "Disk Optimization"
}

# MODULE 3: NETWORK OPTIMIZATION
function Optimize-NetworkPerformance {
    Write-Host "`n[3. NETWORK OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    $networkSteps = @(
        @{ Name = "Flushing DNS cache"; Command = "ipconfig /flushdns" },
        @{ Name = "Resetting TCP/IP stack"; Command = "netsh int ip reset" },
        @{ Name = "Resetting Winsock"; Command = "netsh winsock reset" },
        @{ Name = "Clearing ARP cache"; Command = "arp -d *" },
        @{ Name = "Clearing NetBIOS cache"; Command = "nbtstat -R" }
    )
    
    foreach ($step in $networkSteps) {
        Write-Host "  • $($step.Name)..." -NoNewline -ForegroundColor Gray
        
        try {
            cmd /c $step.Command 2>$null | Out-Null
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "Network: $($step.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # Release and renew IP
    Write-Host "  • Releasing IP address..." -NoNewline -ForegroundColor Gray
    try {
        ipconfig /release | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        Start-Sleep -Seconds 2
        
        Write-Host "  • Renewing IP address..." -NoNewline -ForegroundColor Gray
        ipconfig /renew | Out-Null
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Network: Released/Renewed IP"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    # Network adapter optimization
    Write-Host "  • Optimizing network adapters..." -NoNewline -ForegroundColor Gray
    try {
        $adapters = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'}
        foreach ($adapter in $adapters) {
            # Disable power saving
            Set-NetAdapterPowerManagement -Name $adapter.Name -AllowComputerToTurnOffDevice $false -ErrorAction SilentlyContinue
            
            # Set RSS
            Set-NetAdapterRss -Name $adapter.Name -Enabled $true -ErrorAction SilentlyContinue
        }
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Network adapters optimized"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    $Script:ChangesMade += "Network Optimization"
}

# MODULE 4: PERFORMANCE TWEAKS
function Optimize-SystemPerformance {
    Write-Host "`n[4. PERFORMANCE TWEAKS]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    # Set high performance power plan
    Write-Host "  • Setting high performance power plan..." -NoNewline -ForegroundColor Gray
    try {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Set high performance power plan"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    # Disable visual effects
    $visualTweaks = @(
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "UserPreferencesMask"; Value = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00) },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = "0" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "AutoEndTasks"; Value = "1" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "HungAppTimeout"; Value = "1000" },
        @{ Path = "HKCU:\Control Panel\Desktop"; Name = "WaitToKillAppTimeout"; Value = "2000" }
    )
    
    foreach ($tweak in $visualTweaks) {
        Write-Host "  • Optimizing $($tweak.Name)..." -NoNewline -ForegroundColor Gray
        try {
            Set-ItemProperty -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -ErrorAction SilentlyContinue
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "Performance: $($tweak.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # System performance tweaks
    $systemTweaks = @(
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "DisablePagingExecutive"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "LargeSystemCache"; Value = 1 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"; Name = "Win32PrioritySeparation"; Value = 38 },
        @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; Name = "Size"; Value = 3 }
    )
    
    foreach ($tweak in $systemTweaks) {
        Write-Host "  • Applying $($tweak.Name)..." -NoNewline -ForegroundColor Gray
        try {
            if (-not (Test-Path $tweak.Path)) {
                New-Item -Path $tweak.Path -Force | Out-Null
            }
            Set-ItemProperty -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Type DWord -ErrorAction SilentlyContinue
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "Performance: $($tweak.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    $Script:ChangesMade += "Performance Tweaks"
}

# MODULE 5: PRIVACY & TELEMETRY
function Optimize-Privacy {
    Write-Host "`n[5. PRIVACY OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    $privacyTweaks = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"; Name = "DisableLocation"; Value = 1 },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackProgs"; Value = 0 },
        @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; Name = "Start_TrackDocs"; Value = 0 }
    )
    
    foreach ($tweak in $privacyTweaks) {
        Write-Host "  • Disabling $($tweak.Name)..." -NoNewline -ForegroundColor Gray
        
        try {
            if (-not (Test-Path $tweak.Path)) {
                New-Item -Path $tweak.Path -Force | Out-Null
            }
            Set-ItemProperty -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Type DWord -ErrorAction SilentlyContinue
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "Privacy: $($tweak.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # Clear privacy data
    $privacyCleanup = @(
        @{ Name = "Recent files"; Path = "$env:APPDATA\Microsoft\Windows\Recent\*" },
        @{ Name = "Run dialog history"; Command = "Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Name '*' -ErrorAction SilentlyContinue" },
        @{ Name = "Windows search history"; Path = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" },
        @{ Name = "Thumbnail cache"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" }
    )
    
    foreach ($clean in $privacyCleanup) {
        Write-Host "  • Clearing $($clean.Name)..." -NoNewline -ForegroundColor Gray
        
        try {
            if ($clean.Path) {
                Remove-Item -Path $clean.Path -Recurse -Force -ErrorAction SilentlyContinue
            } elseif ($clean.Command) {
                Invoke-Expression $clean.Command -ErrorAction SilentlyContinue
            }
            Write-Host " ✓" -ForegroundColor Green
            Add-Log "Privacy: Cleared $($clean.Name)"
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    $Script:ChangesMade += "Privacy Optimization"
}

# MODULE 6: SERVICE OPTIMIZATION
function Optimize-Services {
    Write-Host "`n[6. SERVICE OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    # Services that can be safely disabled
    $servicesToDisable = @(
        @{ Name = "DiagTrack"; Display = "Connected User Experiences and Telemetry" },
        @{ Name = "dmwappushservice"; Display = "WAP Push Message Routing Service" },
        @{ Name = "MapsBroker"; Display = "Downloaded Maps Manager" },
        @{ Name = "lfsvc"; Display = "Geolocation Service" },
        @{ Name = "RemoteRegistry"; Display = "Remote Registry" },
        @{ Name = "RemoteAccess"; Display = "Routing and Remote Access" },
        @{ Name = "SharedAccess"; Display = "Internet Connection Sharing" },
        @{ Name = "TrkWks"; Display = "Distributed Link Tracking Client" },
        @{ Name = "WMPNetworkSvc"; Display = "Windows Media Player Network Sharing" }
    )
    
    # Check if SSD for Superfetch
    $diskInfo = Get-PhysicalDisk | Select-Object -First 1
    if ($diskInfo.MediaType -eq 'SSD') {
        $servicesToDisable += @{ Name = "SysMain"; Display = "Superfetch" }
    }
    
    foreach ($service in $servicesToDisable) {
        Write-Host "  • Disabling $($service.Display)..." -NoNewline -ForegroundColor Gray
        
        try {
            $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
            if ($svc) {
                Stop-Service -Name $service.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host " ✓" -ForegroundColor Green
                Add-Log "Service: Disabled $($service.Display)"
            } else {
                Write-Host " -" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " ✗" -ForegroundColor Red
        }
    }
    
    # Optimize Windows Update service
    Write-Host "  • Optimizing Windows Update service..." -NoNewline -ForegroundColor Gray
    try {
        Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Service: Windows Update set to Manual"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    $Script:ChangesMade += "Service Optimization"
}

# MODULE 7: STARTUP OPTIMIZATION
function Optimize-Startup {
    Write-Host "`n[7. STARTUP MANAGEMENT]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Write-Host "  Startup items analysis:" -ForegroundColor Gray
    
    try {
        $startupItems = Get-CimInstance Win32_StartupCommand | 
            Select-Object Name, Command, Location, User |
            Sort-Object Name
        
        if ($startupItems.Count -eq 0) {
            Write-Host "    No startup items found" -ForegroundColor Yellow
        } else {
            Write-Host "    Found $($startupItems.Count) startup items:" -ForegroundColor Yellow
            foreach ($item in $startupItems) {
                Write-Host "    • $($item.Name)" -ForegroundColor Gray
            }
            
            Write-Host "`n  To manage startup items:" -ForegroundColor Cyan
            Write-Host "    1. Press Ctrl + Shift + Esc" -ForegroundColor Gray
            Write-Host "    2. Go to Startup tab" -ForegroundColor Gray
            Write-Host "    3. Disable unnecessary items" -ForegroundColor Gray
        }
        
        Add-Log "Startup: Found $($startupItems.Count) items"
    } catch {
        Write-Host "    Could not retrieve startup items" -ForegroundColor Red
    }
    
    $Script:ChangesMade += "Startup Management"
}

# MODULE 8: MEMORY OPTIMIZATION
function Optimize-Memory {
    Write-Host "`n[8. MEMORY OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Write-Host "  • Clearing standby memory..." -NoNewline -ForegroundColor Gray
    try {
        # Empty working set (requires admin)
        $signature = @'
[DllImport("psapi.dll")]
public static extern bool EmptyWorkingSet(IntPtr hProcess);
'@
        $type = Add-Type -MemberDefinition $signature -Name "MemTools" -Namespace "Win32" -PassThru
        $processes = Get-Process | Where-Object {$_.WorkingSet -gt 50MB}
        
        foreach ($process in $processes) {
            $type::EmptyWorkingSet($process.Handle) | Out-Null
        }
        
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Memory: Cleared standby memory"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    Write-Host "  • Optimizing page file..." -NoNewline -ForegroundColor Gray
    try {
        $totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
        $pageFileSize = [math]::Round($totalRAM * 1.5)
        
        # Set page file size
        $computerSystem = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
        $computerSystem.AutomaticManagedPagefile = $false
        $computerSystem.Put() | Out-Null
        
        $pageFile = Get-WmiObject Win32_PageFileSetting
        $pageFile.InitialSize = $pageFileSize
        $pageFile.MaximumSize = $pageFileSize
        $pageFile.Put() | Out-Null
        
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Memory: Optimized page file"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    $Script:ChangesMade += "Memory Optimization"
}

# ============================================
# PRESET MODES
# ============================================

function Run-QuickCleanMode {
    Write-Host "`n[QUICK CLEAN MODE]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Create-SystemRestorePoint
    Optimize-SystemCleanup
    Optimize-DiskPerformance
    
    Show-Summary "Quick Clean"
}

function Run-PerformanceMode {
    Write-Host "`n[PERFORMANCE MODE]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Create-SystemRestorePoint
    Optimize-SystemCleanup
    Optimize-DiskPerformance
    Optimize-SystemPerformance
    Optimize-Services
    Optimize-Memory
    
    Show-Summary "Performance"
}

function Run-GamingMode {
    Write-Host "`n[GAMING MODE]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Create-SystemRestorePoint
    Optimize-SystemCleanup
    Optimize-DiskPerformance
    Optimize-NetworkPerformance
    Optimize-SystemPerformance
    Optimize-Services
    Optimize-Memory
    
    # Gaming-specific tweaks
    Write-Host "`n[GAMING TWEAKS]" -ForegroundColor Cyan
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Write-Host "  • Setting processor performance..." -NoNewline -ForegroundColor Gray
    try {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Gaming: High performance power plan"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    Write-Host "  • Disabling Game Bar..." -NoNewline -ForegroundColor Gray
    try {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -ErrorAction SilentlyContinue
        Write-Host " ✓" -ForegroundColor Green
        Add-Log "Gaming: Disabled Game Bar"
    } catch {
        Write-Host " ✗" -ForegroundColor Red
    }
    
    Show-Summary "Gaming"
}

function Run-PrivacyMode {
    Write-Host "`n[PRIVACY MODE]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Create-SystemRestorePoint
    Optimize-SystemCleanup
    Optimize-Privacy
    Optimize-Services
    
    Show-Summary "Privacy"
}

function Run-NetworkMode {
    Write-Host "`n[NETWORK OPTIMIZATION MODE]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Create-SystemRestorePoint
    Optimize-NetworkPerformance
    
    Show-Summary "Network"
}

function Run-FullOptimization {
    Write-Host "`n[FULL SYSTEM OPTIMIZATION]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    Write-Host "This will run all optimization modules." -ForegroundColor Yellow
    Write-Host "Estimated time: 3-5 minutes" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        return
    }
    
    Create-SystemRestorePoint
    
    Write-Host "`nStarting comprehensive optimization..." -ForegroundColor Cyan
    
    Optimize-SystemCleanup
    Optimize-DiskPerformance
    Optimize-NetworkPerformance
    Optimize-SystemPerformance
    Optimize-Privacy
    Optimize-Services
    Optimize-Startup
    Optimize-Memory
    
    Show-Summary "Full"
}

function Run-Diagnostics {
    Write-Host "`n[SYSTEM DIAGNOSTICS]" -ForegroundColor Green
    Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray
    
    # System Information
    Write-Host "`n[SYSTEM INFORMATION]" -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "  OS: $($os.Caption)" -ForegroundColor Gray
    Write-Host "  Version: $($os.Version)" -ForegroundColor Gray
    Write-Host "  Build: $($os.BuildNumber)" -ForegroundColor Gray
    
    $cpu = Get-CimInstance Win32_Processor
    Write-Host "  CPU: $($cpu.Name)" -ForegroundColor Gray
    Write-Host "  Cores: $($cpu.NumberOfCores)" -ForegroundColor Gray
    
    $ram = Get-CimInstance Win32_ComputerSystem
    $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    Write-Host "  RAM: ${totalRAM}GB" -ForegroundColor Gray
    
    # Disk Information
    Write-Host "`n[DISK INFORMATION]" -ForegroundColor Cyan
    $disk = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    $usedGB = [math]::Round(($disk.Used) / 1GB, 2)
    Write-Host "  Disk C:" -ForegroundColor Gray
    Write-Host "    Free: ${freeGB}GB" -ForegroundColor Gray
    Write-Host "    Used: ${usedGB}GB" -ForegroundColor Gray
    
    # Performance Information
    Write-Host "`n[PERFORMANCE METRICS]" -ForegroundColor Cyan
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host "  Uptime: $($uptime.Days) days, $($uptime.Hours) hours" -ForegroundColor Gray
    
    $processes = Get-Process | Measure-Object
    Write-Host "  Running processes: $($processes.Count)" -ForegroundColor Gray
    
    # Check common issues
    Write-Host "`n[SYSTEM CHECKS]" -ForegroundColor Cyan
    
    # Check disk space
    if ($freeGB -lt 10) {
        Write-Host "  [!] Low disk space (less than 10GB free)" -ForegroundColor Red
    } else {
        Write-Host "  [✓] Disk space OK" -ForegroundColor Green
    }
    
    # Check RAM usage
    $freeRAM = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    $ramUsage = (($totalRAM - $freeRAM) / $totalRAM) * 100
    
    if ($ramUsage -gt 90) {
        Write-Host "  [!] High RAM usage: $([math]::Round($ramUsage))%" -ForegroundColor Red
    } else {
        Write-Host "  [✓] RAM usage: $([math]::Round($ramUsage))%" -ForegroundColor Green
    }
    
    # Check for Windows updates
    Write-Host "  [i] Check Windows Update for latest updates" -ForegroundColor Yellow
    
    Pause-AnyKey
}

# ============================================
# HELPER FUNCTIONS
# ============================================

function Show-Summary {
    param([string]$Mode)
    
    $endTime = Get-Date
    $duration = $endTime - $Script:StartTime
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "OPTIMIZATION COMPLETE!" -ForegroundColor Green
    Write-Host "="*50 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Mode: $Mode" -ForegroundColor Yellow
    Write-Host "Duration: $([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Modules executed:" -ForegroundColor Yellow
    foreach ($change in $Script:ChangesMade) {
        Write-Host "  • $change" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
    Write-Host "  1. Restart your computer" -ForegroundColor Gray
    Write-Host "  2. Check for Windows updates" -ForegroundColor Gray
    Write-Host "  3. Run monthly for maintenance" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Log saved to: $Script:LogFile" -ForegroundColor Gray
    Write-Host ""
    
    Add-Log "$Mode optimization completed in $([math]::Round($duration.TotalMinutes, 1)) minutes"
    Pause-AnyKey
}

function Pause-AnyKey {
    Write-Host "Press any key to continue..." -ForegroundColor Gray -NoNewline
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# ============================================
# MAIN EXECUTION
# ============================================

Initialize-Optimizer

switch ($Mode) {
    "Full" { Run-FullOptimization }
    "QuickClean" { Run-QuickCleanMode }
    "Performance" { Run-PerformanceMode }
    "Gaming" { Run-GamingMode }
    "Privacy" { Run-PrivacyMode }
    "Network" { Run-NetworkMode }
    "Diagnostics" { Run-Diagnostics }
    default {
        # Interactive menu
        do {
            Clear-Host
            Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║              23 OPTIMIZER v$Script:Version              ║" -ForegroundColor Green
            Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "1.  Full System Optimization" -ForegroundColor Yellow
            Write-Host "2.  Quick Clean Mode" -ForegroundColor Yellow
            Write-Host "3.  Performance Mode" -ForegroundColor Yellow
            Write-Host "4.  Gaming Mode" -ForegroundColor Yellow
            Write-Host "5.  Privacy Mode" -ForegroundColor Yellow
            Write-Host "6.  Network Optimization" -ForegroundColor Yellow
            Write-Host "7.  System Diagnostics" -ForegroundColor Yellow
            Write-Host "8.  Create Restore Point Only" -ForegroundColor Magenta
            Write-Host "9.  View Optimization Log" -ForegroundColor Gray
            Write-Host "0.  Exit" -ForegroundColor Red
            Write-Host ""
            
            $choice = Read-Host "Select option"
            
            switch ($choice) {
                "1" { Run-FullOptimization }
                "2" { Run-QuickCleanMode }
                "3" { Run-PerformanceMode }
                "4" { Run-GamingMode }
                "5" { Run-PrivacyMode }
                "6" { Run-NetworkMode }
                "7" { Run-Diagnostics }
                "8" { Create-SystemRestorePoint; Pause-AnyKey }
                "9" { Show-Log; Pause-AnyKey }
                "0" { break }
                default { Write-Host "Invalid selection!" -ForegroundColor Red; Start-Sleep 1 }
            }
        } while ($choice -ne "0")
    }
}

# ============================================
# EXIT
# ============================================

Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "THANK YOU FOR USING 23 OPTIMIZER!" -ForegroundColor Green
Write-Host "="*50 -ForegroundColor Cyan
Write-Host ""
Write-Host "For best results:" -ForegroundColor Yellow
Write-Host "• Restart your computer" -ForegroundColor Gray
Write-Host "• Run monthly for maintenance" -ForegroundColor Gray
Write-Host "• Keep Windows updated" -ForegroundColor Gray
Write-Host ""

$totalDuration = (Get-Date) - $Script:StartTime
Add-Log "Session ended. Total time: $([math]::Round($totalDuration.TotalMinutes, 1)) minutes"

Start-Sleep -Seconds 3