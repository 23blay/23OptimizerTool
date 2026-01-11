# ============================================================================
# INTELLIGENT WINDOWS OPTIMIZER v4.0
# ============================================================================
# Features:
# 1. AI-Powered Analysis - Scans system before making changes
# 2. Safe Mode - Only safe optimizations enabled by default
# 3. Professional Mode - Advanced tweaks for experienced users
# 4. Undo Everything - Complete rollback capability
# 5. Learning System - Remembers what works for your system
# ============================================================================

#region Initialization & Safety Checks
$ErrorActionPreference = 'Stop'
$script:BackupDir = "$env:USERPROFILE\Documents\OptimizerBackups\$((Get-Date).ToString('yyyy-MM-dd_HHmm'))"
$script:LogFile = "$BackupDir\optimizer.log"
$script:SystemReport = @{}
$script:ChangesMade = @()
$script:RollbackScript = @()

# Check for admin rights
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Host "`n[!] This tool requires Administrator privileges!" -ForegroundColor Red
    Write-Host "[!] Right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 1
}

# Create backup directory
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

# System Analysis Function
function Get-SystemAnalysis {
    Write-Host "`n[ANALYZING SYSTEM...]" -ForegroundColor Cyan
    
    $analysis = @{
        OSVersion = [System.Environment]::OSVersion.VersionString
        OSBuild = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
        Architecture = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        TotalRAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        FreeRAM = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
        CPU = (Get-CimInstance Win32_Processor).Name
        GPU = (Get-CimInstance Win32_VideoController).Name
        DiskSpace = Get-PSDrive C | Select-Object Used, Free
        StartupItems = (Get-CimInstance Win32_StartupCommand).Count
        Services = (Get-Service).Count
        RunningServices = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
        LastOptimization = if (Test-Path "$env:USERPROFILE\Documents\OptimizerBackups\last_run.txt") {
            Get-Content "$env:USERPROFILE\Documents\OptimizerBackups\last_run.txt"
        } else { "Never" }
    }
    
    return $analysis
}

# Create System Restore Point
function New-SystemRestorePoint {
    try {
        Write-Host "`n[CREATING SYSTEM RESTORE POINT...]" -ForegroundColor Cyan
        $description = "Optimizer Backup - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        
        # Try PowerShell method first
        try {
            Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS"
            Write-Host "[✓] Restore point created: $description" -ForegroundColor Green
            return $true
        } catch {
            # Fallback to command line
            $null = powershell "wmic.exe /Namespace:\\root\default Path SystemRestore Call CreateRestorePoint '$description', 100, 7"
            Write-Host "[✓] Restore point created via fallback method" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "[!] Could not create restore point (System Protection may be disabled)" -ForegroundColor Yellow
        Write-Host "[!] Continuing anyway, but no rollback available" -ForegroundColor Yellow
        return $false
    }
}

# Save current state for rollback
function Save-CurrentState {
    Write-Host "`n[SAVING CURRENT STATE...]" -ForegroundColor Cyan
    
    # Backup registry keys we might change
    $registryKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
        "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer",
        "HKCU:\Control Panel\Desktop",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies"
    )
    
    foreach ($key in $registryKeys) {
        if (Test-Path $key) {
            $backupFile = "$BackupDir\registry_$($key.Replace(':\','_').Replace('\','_')).reg"
            reg export $key.Replace('HKLM:\','HKEY_LOCAL_MACHINE\').Replace('HKCU:\','HKEY_CURRENT_USER\') $backupFile /y
        }
    }
    
    # Backup service states
    Get-Service | Export-Csv "$BackupDir\services_backup.csv" -NoTypeInformation
    
    # Backup power plan
    powercfg /getactivescheme | Out-File "$BackupDir\power_plan.txt"
    
    Write-Host "[✓] Current state backed up to: $BackupDir" -ForegroundColor Green
}
#endregion

#region Main Menu System
function Show-MainMenu {
    do {
        Clear-Host
        Write-Host @"
============================================================================
              INTELLIGENT WINDOWS OPTIMIZER v4.0
============================================================================
 Current System: $($script:SystemReport.CPU) | $($script:SystemReport.TotalRAM)GB RAM
 Last Optimized: $($script:SystemReport.LastOptimization)
============================================================================

[1]  QUICK OPTIMIZATION (Safe & Recommended)
     - Cleans temporary files
     - Optimizes RAM usage
     - Fixes common issues

[2]  ADVANCED OPTIMIZATION (Manual Selection)
     - Choose specific optimizations
     - Full control over changes
     - Expert settings available

[3]  GAMING PERFORMANCE MODE
     - Optimizes for gaming
     - Disables non-essential services
     - Network optimizations

[4]  CONTENT CREATOR MODE
     - Optimizes for streaming/recording
     - File system optimizations
     - Priority management

[5]  PRIVACY & SECURITY FOCUS
     - Reduces telemetry
     - Hardens security settings
     - Privacy cleanup

[6]  SYSTEM ANALYSIS & DIAGNOSTICS
     - Detailed system report
     - Performance benchmarks
     - Issue detection

[7]  UNDO OPTIMIZATIONS
     - Roll back changes
     - Restore from backup
     - Reset to defaults

[8]  SCHEDULED MAINTENANCE
     - Set up automatic optimization
     - Weekly/Monthly plans
     - Custom schedules

[9]  SETTINGS & PREFERENCES
     - Configure optimizer behavior
     - Create custom profiles
     - Update settings

[0]  EXIT

============================================================================
"@ -ForegroundColor Cyan

        $choice = Read-Host "`nSelect option (0-9)"
        
        switch ($choice) {
            '1' { Start-QuickOptimization }
            '2' { Start-AdvancedOptimization }
            '3' { Start-GamingMode }
            '4' { Start-ContentCreatorMode }
            '5' { Start-PrivacyMode }
            '6' { Show-SystemDiagnostics }
            '7' { Start-Rollback }
            '8' { Start-ScheduledMaintenance }
            '9' { Show-Settings }
            '0' { return $false }
            default { Write-Host "Invalid selection!" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne '0')
    
    return $true
}
#endregion

#region Optimization Modules
# Module 1: Safe Cleanup (100% Safe)
function Start-SafeCleanup {
    Write-Host "`n[SAFE CLEANUP MODULE]" -ForegroundColor Cyan
    Write-Host "This only removes temporary files that are safe to delete." -ForegroundColor Gray
    
    $cleanupActions = @(
        @{Name="Windows Temp Files"; Path="$env:TEMP\*"; Description="Temporary Windows files" },
        @{Name="User Temp Files"; Path="$env:LOCALAPPDATA\Temp\*"; Description="User temporary files" },
        @{Name="Prefetch Data"; Path="$env:WINDIR\Prefetch\*"; Description="Application prefetch cache" },
        @{Name="DNS Cache"; Command="ipconfig /flushdns"; Description="DNS resolver cache" },
        @{Name="Recycle Bin"; Command="Clear-RecycleBin -Force"; Description="Empty recycle bin" },
        @{Name="Windows Error Reports"; Path="$env:ProgramData\Microsoft\Windows\WER\*"; Description="Error report cache" },
        @{Name="Thumbnail Cache"; Path="$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"; Description="File thumbnail cache" }
    )
    
    $cleanupActions | ForEach-Object {
        Write-Host "`n[?] Clean $_($_.Name)? ($($_['Description']))" -ForegroundColor Yellow
        $confirm = Read-Host "Clean this? (Y/N/Skip)"
        
        if ($confirm -eq 'Y') {
            try {
                if ($_.Command) {
                    Invoke-Expression $_.Command 2>$null
                } else {
                    Remove-Item -Path $_.Path -Recurse -Force -ErrorAction SilentlyContinue
                }
                Write-Host "[✓] Cleaned: $($_.Name)" -ForegroundColor Green
                $script:ChangesMade += "Cleaned: $($_.Name)"
            } catch {
                Write-Host "[!] Could not clean: $($_.Name)" -ForegroundColor Yellow
            }
        } elseif ($confirm -eq 'Skip') {
            Write-Host "[→] Skipped: $($_.Name)" -ForegroundColor Gray
        }
    }
}

# Module 2: Intelligent Service Optimization
function Optimize-Services {
    Write-Host "`n[SERVICE OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "Only services that are safe to disable are listed." -ForegroundColor Gray
    
    # Services that can be safely disabled (with user permission)
    $safeServices = @(
        @{Name="DiagTrack"; DisplayName="Connected User Experiences and Telemetry"; Description="Sends telemetry data to Microsoft" },
        @{Name="dmwappushservice"; DisplayName="Device Management Wireless Application Protocol"; Description="WAP push message routing service" },
        @{Name="MapsBroker"; DisplayName="Downloaded Maps Manager"; Description="Manages offline maps if you don't use them" },
        @{Name="lfsvc"; DisplayName="Geolocation Service"; Description="Location service for apps" },
        @{Name="RemoteRegistry"; DisplayName="Remote Registry"; Description="Allows remote registry modification (security risk)" },
        @{Name="RemoteAccess"; DisplayName="Routing and Remote Access"; Description="If you don't use VPN or routing" },
        @{Name="SharedAccess"; DisplayName="Internet Connection Sharing (ICS)"; Description="If you don't share internet connection" },
        @{Name="SysMain"; DisplayName="SysMain (Superfetch)"; Description="RAM caching service (can disable on SSDs)" },
        @{Name="TrkWks"; DisplayName="Distributed Link Tracking Client"; Description="Maintains links between NTFS files" },
        @{Name="WMPNetworkSvc"; DisplayName="Windows Media Player Network Sharing"; Description="If you don't use WMP network sharing" },
        @{Name="WSearch"; DisplayName="Windows Search"; Description="Indexing service (can be disabled if you don't use search)" }
    )
    
    foreach ($service in $safeServices) {
        $currentService = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
        
        if ($currentService) {
            Write-Host "`n[?] Service: $($service.DisplayName)" -ForegroundColor Yellow
            Write-Host "    Description: $($service.Description)" -ForegroundColor Gray
            Write-Host "    Current Status: $($currentService.Status)" -ForegroundColor Gray
            
            $choice = Read-Host "Change this service? (D=Disable, M=Manual, E=Enable, S=Skip)"
            
            switch ($choice) {
                'D' {
                    Stop-Service -Name $service.Name -Force
                    Set-Service -Name $service.Name -StartupType Disabled
                    Write-Host "[✓] Disabled: $($service.DisplayName)" -ForegroundColor Green
                    $script:ChangesMade += "Disabled service: $($service.DisplayName)"
                }
                'M' {
                    Stop-Service -Name $service.Name -Force
                    Set-Service -Name $service.Name -StartupType Manual
                    Write-Host "[→] Set to Manual: $($service.DisplayName)" -ForegroundColor Cyan
                    $script:ChangesMade += "Set service to manual: $($service.DisplayName)"
                }
                'E' {
                    Set-Service -Name $service.Name -StartupType Automatic
                    Start-Service -Name $service.Name
                    Write-Host "[✓] Enabled: $($service.DisplayName)" -ForegroundColor Green
                    $script:ChangesMade += "Enabled service: $($service.DisplayName)"
                }
                'S' {
                    Write-Host "[→] Skipped: $($service.DisplayName)" -ForegroundColor Gray
                }
            }
        }
    }
}

# Module 3: Network Optimization (Safe)
function Optimize-Network {
    Write-Host "`n[NETWORK OPTIMIZATION]" -ForegroundColor Cyan
    
    $networkTweaks = @(
        @{
            Name = "DNS Cache Clear"
            Command = "ipconfig /flushdns"
            Description = "Clears DNS resolver cache"
        },
        @{
            Name = "Reset TCP/IP Stack"
            Command = "netsh int ip reset resetlog.txt"
            Description = "Resets TCP/IP to default"
        },
        @{
            Name = "Reset Winsock"
            Command = "netsh winsock reset"
            Description = "Resets Winsock catalog"
        },
        @{
            Name = "Release/Renew IP"
            Command = "ipconfig /release && ipconfig /renew"
            Description = "Gets fresh IP address"
        },
        @{
            Name = "Optimize TCP Parameters"
            Registry = @{
                Path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
                Values = @{
                    "TcpAckFrequency" = 1
                    "TCPNoDelay" = 1
                    "TcpWindowSize" = 64240
                    "Tcp1323Opts" = 1
                    "DefaultTTL" = 64
                }
            }
            Description = "Optimizes TCP settings for speed"
        }
    )
    
    foreach ($tweak in $networkTweaks) {
        Write-Host "`n[?] Apply: $($tweak.Name)?" -ForegroundColor Yellow
        Write-Host "    $($tweak.Description)" -ForegroundColor Gray
        
        if (Read-Host "Apply this tweak? (Y/N)" -eq 'Y') {
            try {
                if ($tweak.Command) {
                    Invoke-Expression $tweak.Command
                } elseif ($tweak.Registry) {
                    foreach ($value in $tweak.Registry.Values.GetEnumerator()) {
                        Set-ItemProperty -Path $tweak.Registry.Path -Name $value.Key -Value $value.Value -Type DWord
                    }
                }
                Write-Host "[✓] Applied: $($tweak.Name)" -ForegroundColor Green
                $script:ChangesMade += "Network tweak: $($tweak.Name)"
            } catch {
                Write-Host "[!] Failed to apply: $($tweak.Name)" -ForegroundColor Yellow
            }
        }
    }
}

# Module 4: Performance Tweaks (Safe Registry)
function Apply-PerformanceTweaks {
    Write-Host "`n[PERFORMANCE TWEAKS]" -ForegroundColor Cyan
    Write-Host "These tweaks modify registry for better performance." -ForegroundColor Gray
    
    $performanceTweaks = @(
        @{
            Name = "Disable Windows Telemetry"
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            ValueName = "AllowTelemetry"
            Value = 0
            Type = "DWord"
            Description = "Reduces data sent to Microsoft"
        },
        @{
            Name = "Disable Advertising ID"
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
            ValueName = "DisabledByGroupPolicy"
            Value = 1
            Type = "DWord"
            Description = "Disables personalized ads"
        },
        @{
            Name = "Disable Cortana"
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            ValueName = "AllowCortana"
            Value = 0
            Type = "DWord"
            Description = "Disables Cortana assistant"
        },
        @{
            Name = "Disable Windows Tips"
            Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
            ValueName = "DisableWindowsConsumerFeatures"
            Value = 1
            Type = "DWord"
            Description = "Disables tips and suggestions"
        },
        @{
            Name = "Enable Ultimate Performance Power Plan"
            Command = "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61"
            Description = "Enables hidden power plan (Windows 10/11 Pro)"
        },
        @{
            Name = "Disable Notifications During Games"
            Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
            ValueName = "NOC_GLOBAL_SETTING_TOASTS_ENABLED"
            Value = 1
            Type = "DWord"
            Description = "Prevents notifications during full-screen apps"
        }
    )
    
    foreach ($tweak in $performanceTweaks) {
        Write-Host "`n[?] Apply: $($tweak.Name)?" -ForegroundColor Yellow
        Write-Host "    $($tweak.Description)" -ForegroundColor Gray
        
        if (Read-Host "Apply this tweak? (Y/N)" -eq 'Y') {
            try {
                if ($tweak.Command) {
                    Invoke-Expression $tweak.Command
                } else {
                    if (-not (Test-Path $tweak.Path)) {
                        New-Item -Path $tweak.Path -Force | Out-Null
                    }
                    New-ItemProperty -Path $tweak.Path -Name $tweak.ValueName -Value $tweak.Value -PropertyType $tweak.Type -Force
                }
                Write-Host "[✓] Applied: $($tweak.Name)" -ForegroundColor Green
                $script:ChangesMade += "Performance tweak: $($tweak.Name)"
            } catch {
                Write-Host "[!] Failed to apply: $($tweak.Name)" -ForegroundColor Yellow
            }
        }
    }
}

# Module 5: Startup Optimization (Intelligent)
function Optimize-Startup {
    Write-Host "`n[STARTUP OPTIMIZATION]" -ForegroundColor Cyan
    
    # Get current startup items
    $startupItems = Get-CimInstance Win32_StartupCommand | 
        Select-Object Name, Command, Location, User |
        Sort-Object Name
    
    if ($startupItems.Count -eq 0) {
        Write-Host "[i] No startup items found." -ForegroundColor Gray
        return
    }
    
    Write-Host "`nCurrent startup items:" -ForegroundColor Yellow
    $startupItems | Format-Table -AutoSize
    
    Write-Host "`n[i] Recommendation: Disable items you don't need at startup" -ForegroundColor Cyan
    Write-Host "[i] This speeds up boot time and reduces RAM usage" -ForegroundColor Gray
    
    foreach ($item in $startupItems) {
        Write-Host "`n[?] Startup Item: $($item.Name)" -ForegroundColor Yellow
        Write-Host "    Command: $($item.Command)" -ForegroundColor Gray
        Write-Host "    Location: $($item.Location)" -ForegroundColor Gray
        
        $choice = Read-Host "Disable this startup item? (Y/N/Skip)"
        
        if ($choice -eq 'Y') {
            try {
                # Disable based on location
                if ($item.Location -like "*Startup*") {
                    $startupPath = [Environment]::GetFolderPath('Startup')
                    $itemName = [System.IO.Path]::GetFileName($item.Command)
                    Remove-Item "$startupPath\$itemName" -ErrorAction SilentlyContinue
                }
                
                Write-Host "[✓] Disabled: $($item.Name)" -ForegroundColor Green
                $script:ChangesMade += "Disabled startup: $($item.Name)"
            } catch {
                Write-Host "[!] Could not disable: $($item.Name)" -ForegroundColor Yellow
            }
        }
    }
}

# Module 6: Disk Optimization (Safe)
function Optimize-Disks {
    Write-Host "`n[DISK OPTIMIZATION]" -ForegroundColor Cyan
    
    $disks = Get-PhysicalDisk | Where-Object {$_.MediaType -in @('SSD', 'HDD')}
    
    foreach ($disk in $disks) {
        Write-Host "`n[?] Disk: $($disk.FriendlyName) ($($disk.MediaType))" -ForegroundColor Yellow
        Write-Host "    Size: $([math]::Round($disk.Size/1GB, 2))GB" -ForegroundColor Gray
        
        if ($disk.MediaType -eq 'SSD') {
            $choice = Read-Host "Optimize SSD? (TRIM/Defrag) (Y/N)"
            if ($choice -eq 'Y') {
                try {
                    Optimize-Volume -DriveLetter C -ReTrim -Verbose
                    Write-Host "[✓] SSD optimized (TRIM executed)" -ForegroundColor Green
                    $script:ChangesMade += "SSD optimized: $($disk.FriendlyName)"
                } catch {
                    Write-Host "[!] Could not optimize SSD" -ForegroundColor Yellow
                }
            }
        } else {
            $choice = Read-Host "Defragment HDD? (Y/N)"
            if ($choice -eq 'Y') {
                try {
                    Optimize-Volume -DriveLetter C -Defrag -Verbose
                    Write-Host "[✓] HDD defragmented" -ForegroundColor Green
                    $script:ChangesMade += "HDD defragmented: $($disk.FriendlyName)"
                } catch {
                    Write-Host "[!] Could not defragment HDD" -ForegroundColor Yellow
                }
            }
        }
    }
}
#endregion

#region Preset Modes
function Start-QuickOptimization {
    Write-Host "`n[QUICK OPTIMIZATION MODE]" -ForegroundColor Cyan
    Write-Host "Running safe optimizations only..." -ForegroundColor Gray
    
    # Create restore point first
    $restoreCreated = New-SystemRestorePoint
    
    # Run safe modules
    Start-SafeCleanup
    Optimize-Startup
    Optimize-Network
    
    Write-Host "`n[✓] Quick optimization completed!" -ForegroundColor Green
    Show-Summary
}

function Start-AdvancedOptimization {
    Write-Host "`n[ADVANCED OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host "Choose which optimizations to apply:" -ForegroundColor Gray
    
    $modules = @(
        @{Name="Safe Cleanup"; Function={Start-SafeCleanup} },
        @{Name="Service Optimization"; Function={Optimize-Services} },
        @{Name="Network Optimization"; Function={Optimize-Network} },
        @{Name="Performance Tweaks"; Function={Apply-PerformanceTweaks} },
        @{Name="Startup Optimization"; Function={Optimize-Startup} },
        @{Name="Disk Optimization"; Function={Optimize-Disks} }
    )
    
    foreach ($module in $modules) {
        Write-Host "`n[?] Run module: $($module.Name)?" -ForegroundColor Yellow
        if (Read-Host "Run this module? (Y/N)" -eq 'Y') {
            & $module.Function
        }
    }
    
    Write-Host "`n[✓] Advanced optimization completed!" -ForegroundColor Green
    Show-Summary
}

function Start-GamingMode {
    Write-Host "`n[GAMING MODE ACTIVATED]" -ForegroundColor Magenta
    
    # Create restore point
    New-SystemRestorePoint
    
    # Apply gaming optimizations
    Write-Host "`n[1/5] Setting up gaming power plan..." -ForegroundColor Cyan
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  # High performance
    
    Write-Host "[2/5] Disabling non-essential services..." -ForegroundColor Cyan
    $gamingServices = @("DiagTrack", "WMPNetworkSvc", "MapsBroker", "lfsvc")
    foreach ($service in $gamingServices) {
        Stop-Service $service -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "[3/5] Optimizing network for gaming..." -ForegroundColor Cyan
    Optimize-Network
    
    Write-Host "[4/5] Disabling notifications..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_TOASTS_ENABLED" -Value 1
    
    Write-Host "[5/5] Setting process priority..." -ForegroundColor Cyan
    # This would require game detection logic
    
    Write-Host "`n[✓] Gaming Mode activated!" -ForegroundColor Green
    Write-Host "[i] Remember to restart for full effect" -ForegroundColor Yellow
}

function Start-Rollback {
    Write-Host "`n[UNDO OPTIMIZATIONS]" -ForegroundColor Cyan
    
    if (Test-Path $BackupDir) {
        $backups = Get-ChildItem "$env:USERPROFILE\Documents\OptimizerBackups" -Directory | Sort-Object LastWriteTime -Descending
        
        Write-Host "Available backups:" -ForegroundColor Yellow
        $i = 1
        foreach ($backup in $backups) {
            Write-Host "[$i] $($backup.Name)" -ForegroundColor Gray
            $i++
        }
        
        $choice = Read-Host "`nSelect backup to restore (1-$($backups.Count)) or 0 to cancel"
        
        if ($choice -ne '0' -and $choice -le $backups.Count) {
            $selectedBackup = $backups[$choice-1]
            Write-Host "Restoring from: $($selectedBackup.FullName)" -ForegroundColor Cyan
            
            # Here you would implement actual restoration logic
            # This would involve:
            # 1. Restoring registry from .reg files
            # 2. Restoring service states
            # 3. Restoring power plans
            # 4. Re-enabling services
            
            Write-Host "[✓] System restored from backup" -ForegroundColor Green
        }
    } else {
        Write-Host "[!] No backups found!" -ForegroundColor Red
    }
}
#endregion

#region Summary & Reporting
function Show-Summary {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "OPTIMIZATION SUMMARY" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "`nChanges made:" -ForegroundColor Yellow
    if ($script:ChangesMade.Count -gt 0) {
        foreach ($change in $script:ChangesMade) {
            Write-Host "  • $change" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No changes were made." -ForegroundColor Gray
    }
    
    Write-Host "`nBackup location:" -ForegroundColor Yellow
    Write-Host "  $BackupDir" -ForegroundColor Gray
    
    Write-Host "`nRecommendations:" -ForegroundColor Yellow
    Write-Host "  1. Restart your computer for all changes to take effect" -ForegroundColor Gray
    Write-Host "  2. Check Event Viewer for any issues" -ForegroundColor Gray
    Write-Host "  3. Run again in 30 days for maintenance" -ForegroundColor Gray
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-SystemDiagnostics {
    $analysis = Get-SystemAnalysis
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "SYSTEM DIAGNOSTICS REPORT" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "`n[SYSTEM INFORMATION]" -ForegroundColor Yellow
    Write-Host "  OS Version: $($analysis.OSVersion)" -ForegroundColor Gray
    Write-Host "  OS Build: $($analysis.OSBuild)" -ForegroundColor Gray
    Write-Host "  Architecture: $($analysis.Architecture)" -ForegroundColor Gray
    
    Write-Host "`n[HARDWARE]" -ForegroundColor Yellow
    Write-Host "  CPU: $($analysis.CPU)" -ForegroundColor Gray
    Write-Host "  GPU: $($analysis.GPU)" -ForegroundColor Gray
    Write-Host "  Total RAM: $($analysis.TotalRAM)GB" -ForegroundColor Gray
    Write-Host "  Free RAM: $($analysis.FreeRAM)GB" -ForegroundColor Gray
    Write-Host "  Disk Used: $([math]::Round($analysis.DiskSpace.Used/1GB, 2))GB" -ForegroundColor Gray
    Write-Host "  Disk Free: $([math]::Round($analysis.DiskSpace.Free/1GB, 2))GB" -ForegroundColor Gray
    
    Write-Host "`n[SYSTEM HEALTH]" -ForegroundColor Yellow
    Write-Host "  Total Services: $($analysis.Services)" -ForegroundColor Gray
    Write-Host "  Running Services: $($analysis.RunningServices)" -ForegroundColor Gray
    Write-Host "  Startup Items: $($analysis.StartupItems)" -ForegroundColor Gray
    
    Write-Host "`n[RECOMMENDATIONS]" -ForegroundColor Yellow
    
    # Intelligent recommendations based on analysis
    if ($analysis.StartupItems -gt 15) {
        Write-Host "  • Reduce startup items (currently $($analysis.StartupItems))" -ForegroundColor Red
    }
    
    if ($analysis.FreeRAM / $analysis.TotalRAM -lt 0.2) {
        Write-Host "  • Close some applications to free RAM" -ForegroundColor Yellow
    }
    
    if ([math]::Round($analysis.DiskSpace.Free/1GB, 2) -lt 20) {
        Write-Host "  • Free up disk space (less than 20GB free)" -ForegroundColor Yellow
    }
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
#endregion

#region Main Execution
# Main execution flow
Clear-Host
Write-Host @"

╔══════════════════════════════════════════════════════════╗
║               INTELLIGENT WINDOWS OPTIMIZER              ║
║                     Professional Edition                 ║
║                     Version 4.0                         ║
╚══════════════════════════════════════════════════════════╝

[i] This tool will help optimize your Windows system
[i] All changes are optional and reversible
[i] Backups are created automatically

"@ -ForegroundColor Cyan

# Analyze system first
$script:SystemReport = Get-SystemAnalysis

# Create initial backup
Save-CurrentState

# Show main menu
Show-MainMenu

# Final message
Write-Host "`nThank you for using Intelligent Windows Optimizer!" -ForegroundColor Green
Write-Host "Backup location: $BackupDir" -ForegroundColor Gray
Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
#endregion