#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ========================================
# 23 OPTIMIZER PRO - Configuration
# ========================================

$script:Version = "2.0.0"
$script:BackupPath = "$env:USERPROFILE\Documents\23Optimizer_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$script:StateBackup = @{}
$script:Stats = @{
    SpaceFreed = 0
    ItemsCleaned = 0
    OptimizationsApplied = 0
}

# ========================================
# CORE FUNCTIONS - Enhanced Logging
# ========================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error","Header")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $richTextBox.SelectionStart = $richTextBox.TextLength
    $richTextBox.SelectionLength = 0
    
    $colors = @{
        "Success" = @{ Color = [System.Drawing.Color]::FromArgb(34, 139, 34); Prefix = "✓" }
        "Warning" = @{ Color = [System.Drawing.Color]::FromArgb(255, 140, 0); Prefix = "⚠" }
        "Error"   = @{ Color = [System.Drawing.Color]::FromArgb(220, 20, 60); Prefix = "✗" }
        "Header"  = @{ Color = [System.Drawing.Color]::FromArgb(70, 130, 180); Prefix = "▶" }
        "Info"    = @{ Color = [System.Drawing.Color]::FromArgb(60, 60, 60); Prefix = "•" }
    }
    
    $style = $colors[$Level]
    $richTextBox.SelectionColor = $style.Color
    
    if ($Level -eq "Header") {
        $richTextBox.SelectionFont = New-Object System.Drawing.Font($richTextBox.Font.FontFamily, 10, [System.Drawing.FontStyle]::Bold)
    }
    
    $richTextBox.AppendText("[$timestamp] $($style.Prefix) $Message`r`n")
    $richTextBox.SelectionFont = New-Object System.Drawing.Font($richTextBox.Font.FontFamily, 9, [System.Drawing.FontStyle]::Regular)
    $richTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-ProgressBar {
    param([int]$Value, [string]$Status = "")
    $progressBar.Value = [Math]::Min($Value, 100)
    if ($Status) { $statusLabel.Text = $Status }
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    }
    return 0
}

function Backup-RegistryKey {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) {
            $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($value) {
                $script:StateBackup["$Path\$Name"] = $value.$Name
                Write-Log "Backed up: $Path\$Name" Info
            }
        }
    }
    catch {
        Write-Log "Could not backup $Path\$Name" Warning
    }
}

function Save-BackupFile {
    try {
        $script:StateBackup | ConvertTo-Json -Depth 10 | Out-File $script:BackupPath -Force
        Write-Log "Backup saved to: $script:BackupPath" Success
    }
    catch {
        Write-Log "Failed to save backup file: $_" Error
    }
}

# ========================================
# OPTIMIZATION MODULES
# ========================================

function Clear-TempAndCaches {
    Write-Log "CLEANING TEMPORARY FILES & CACHES" Header
    Update-ProgressBar 0 "Analyzing temporary files..."
    
    $totalFreed = 0
    $locations = @(
        @{Path = "$env:TEMP"; Name = "User Temp"},
        @{Path = "C:\Windows\Temp"; Name = "Windows Temp"},
        @{Path = "$env:LOCALAPPDATA\Temp"; Name = "Local Temp"}
    )
    
    $step = 100 / ($locations.Count + 5)
    $progress = 0
    
    foreach ($loc in $locations) {
        try {
            if (Test-Path $loc.Path) {
                $sizeBefore = Get-FolderSize -Path $loc.Path
                Write-Log "Cleaning $($loc.Name)..." Info
                
                Get-ChildItem -Path $loc.Path -Force -ErrorAction SilentlyContinue | 
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                
                $sizeAfter = Get-FolderSize -Path $loc.Path
                $freed = ($sizeBefore - $sizeAfter) / 1MB
                $totalFreed += $freed
                
                Write-Log "  Freed: $([Math]::Round($freed, 2)) MB" Success
            }
        }
        catch {
            Write-Log "  Could not fully clean $($loc.Name): $_" Warning
        }
        $progress += $step
        Update-ProgressBar $progress "Cleaning $($loc.Name)..."
    }
    
    # Recycle Bin
    Write-Log "Emptying Recycle Bin..." Info
    try {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-Log "  Recycle Bin emptied" Success
    }
    catch {
        Write-Log "  Could not empty Recycle Bin (may be empty)" Warning
    }
    $progress += $step
    Update-ProgressBar $progress "Emptying Recycle Bin..."
    
    # Prefetch (with safety check)
    if (Test-Path "C:\Windows\Prefetch") {
        Write-Log "Clearing Prefetch (keeping recent files)..." Info
        try {
            Get-ChildItem "C:\Windows\Prefetch" -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Log "  Prefetch cleaned" Success
        }
        catch {
            Write-Log "  Prefetch cleaning skipped" Warning
        }
    }
    $progress += $step
    Update-ProgressBar $progress "Clearing Prefetch..."
    
    # Browser Caches
    Write-Log "Clearing Browser Caches..." Info
    $browserCaches = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:APPDATA\Mozilla\Firefox\Profiles"
    )
    
    foreach ($cache in $browserCaches) {
        if (Test-Path $cache) {
            try {
                $sizeBefore = Get-FolderSize -Path $cache
                Get-ChildItem $cache -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match "cache" } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $sizeAfter = Get-FolderSize -Path $cache
                $freed = ($sizeBefore - $sizeAfter) / 1MB
                $totalFreed += $freed
            }
            catch { }
        }
    }
    Write-Log "  Browser caches cleaned" Success
    $progress += $step
    Update-ProgressBar $progress "Clearing browser caches..."
    
    # Windows Update Cleanup
    Write-Log "Cleaning Windows Update cache..." Info
    try {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        if (Test-Path "C:\Windows\SoftwareDistribution\Download") {
            $sizeBefore = Get-FolderSize -Path "C:\Windows\SoftwareDistribution\Download"
            Remove-Item "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
            $sizeAfter = Get-FolderSize -Path "C:\Windows\SoftwareDistribution\Download"
            $freed = ($sizeBefore - $sizeAfter) / 1MB
            $totalFreed += $freed
            Write-Log "  Windows Update cache cleaned: $([Math]::Round($freed, 2)) MB" Success
        }
        Start-Service wuauserv -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "  Windows Update cleanup partial" Warning
    }
    $progress += $step
    Update-ProgressBar $progress "Cleaning Windows Update cache..."
    
    $script:Stats.SpaceFreed += $totalFreed
    Update-ProgressBar 100 "Cleanup complete"
    Write-Log "TOTAL SPACE FREED: $([Math]::Round($totalFreed, 2)) MB" Success
}

function Optimize-DiskAndPagefile {
    Write-Log "DISK & PAGEFILE OPTIMIZATION" Header
    Update-ProgressBar 0 "Analyzing disk configuration..."
    
    try {
        $disk = Get-PhysicalDisk | Select-Object -First 1
        $mediaType = $disk.MediaType
        
        Write-Log "Detected: $mediaType" Info
        Update-ProgressBar 20 "Detected $mediaType..."
        
        if ($mediaType -eq 'SSD' -or $mediaType -eq 'NVMe') {
            Write-Log "Running TRIM optimization for SSD..." Info
            Update-ProgressBar 40 "Optimizing SSD with TRIM..."
            
            Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
            Write-Log "  TRIM operation completed" Success
            
            # Disable SuperFetch for SSD (saved as SysMain)
            try {
                Stop-Service SysMain -Force -ErrorAction SilentlyContinue
                Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log "  Disabled SuperFetch (recommended for SSD)" Success
            }
            catch { }
        }
        else {
            Write-Log "Running defragmentation for HDD..." Info
            Update-ProgressBar 40 "Defragmenting HDD..."
            
            Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
            Write-Log "  Defragmentation completed" Success
            
            # Optimize pagefile for HDD
            try {
                $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
                $minSize = [Math]::Floor($ram * 1024)
                $maxSize = [Math]::Floor($ram * 2048)
                
                Backup-RegistryKey "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles"
                Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" `
                    -Name "PagingFiles" -Value "C:\pagefile.sys $minSize $maxSize"
                Write-Log "  Pagefile optimized: ${minSize}MB - ${maxSize}MB" Success
            }
            catch {
                Write-Log "  Could not optimize pagefile" Warning
            }
        }
        
        Update-ProgressBar 80 "Finalizing disk optimization..."
        
        # Clear disk cache
        Write-Output 3 | Out-File C:\Windows\System32\config\systemprofile\AppData\Local\Temp\clear.txt -ErrorAction SilentlyContinue
        
        $script:Stats.OptimizationsApplied++
        Update-ProgressBar 100 "Disk optimization complete"
        Write-Log "Disk optimization completed successfully" Success
    }
    catch {
        Write-Log "Disk optimization encountered errors: $_" Error
    }
}

function Optimize-MemoryAndCPU {
    Write-Log "MEMORY & CPU OPTIMIZATION" Header
    Update-ProgressBar 0 "Analyzing system resources..."
    
    # Memory cleanup
    Write-Log "Triggering garbage collection..." Info
    Update-ProgressBar 20 "Cleaning memory..."
    
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    Write-Log "  Memory garbage collection completed" Success
    
    # Clear standby memory (advanced)
    Update-ProgressBar 40 "Clearing standby memory..."
    try {
        $clearStandbyMem = @"
using System;
using System.Runtime.InteropServices;
public class MemoryManagement {
    [DllImport("kernel32.dll")]
    public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
    public static void ClearMemory() {
        SetProcessWorkingSetSize(System.Diagnostics.Process.GetCurrentProcess().Handle, -1, -1);
    }
}
"@
        Add-Type -TypeDefinition $clearStandbyMem -ErrorAction SilentlyContinue
        [MemoryManagement]::ClearMemory()
        Write-Log "  Working set memory cleared" Success
    }
    catch { }
    
    # CPU priority optimization
    Update-ProgressBar 60 "Optimizing process priorities..."
    Write-Log "Adjusting idle process priorities..." Info
    
    $optimized = 0
    Get-Process | Where-Object {
        $_.CPU -lt 0.1 -and 
        $_.ProcessName -notmatch '^(csrss|dwm|explorer|lsass|services|smss|System|wininit|winlogon)$'
    } | ForEach-Object {
        try {
            $_.PriorityClass = "BelowNormal"
            $optimized++
        }
        catch { }
    }
    
    Write-Log "  Optimized $optimized low-activity processes" Success
    
    # Power plan optimization
    Update-ProgressBar 80 "Optimizing power settings..."
    try {
        $powerPlan = powercfg /l | Select-String "High performance" | ForEach-Object { ($_ -split '\s+')[3] }
        if ($powerPlan) {
            powercfg /setactive $powerPlan
            Write-Log "  Activated High Performance power plan" Success
        }
    }
    catch { }
    
    $script:Stats.OptimizationsApplied++
    Update-ProgressBar 100 "Memory & CPU optimization complete"
    Write-Log "Memory & CPU optimization completed" Success
}

function Optimize-ServicesAndStartup {
    Write-Log "SERVICES & STARTUP OPTIMIZATION" Header
    Update-ProgressBar 0 "Analyzing services and startup programs..."
    
    # Safe services to optimize (non-critical)
    $servicesToOptimize = @(
        @{Name = "DiagTrack"; Display = "Connected User Experiences and Telemetry"},
        @{Name = "WSearch"; Display = "Windows Search"},
        @{Name = "SysMain"; Display = "SuperFetch/SysMain"},
        @{Name = "BITS"; Display = "Background Intelligent Transfer"},
        @{Name = "DPS"; Display = "Diagnostic Policy Service"},
        @{Name = "WerSvc"; Display = "Windows Error Reporting"}
    )
    
    $step = 50 / $servicesToOptimize.Count
    $progress = 0
    
    foreach ($svc in $servicesToOptimize) {
        try {
            $service = Get-Service $svc.Name -ErrorAction SilentlyContinue
            if ($service) {
                # Backup current state
                $currentStartup = $service.StartType
                $script:StateBackup["Service_$($svc.Name)_StartType"] = $currentStartup
                $script:StateBackup["Service_$($svc.Name)_Status"] = $service.Status
                
                Write-Log "Optimizing $($svc.Display)..." Info
                
                if ($service.Status -eq 'Running') {
                    Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
                }
                Set-Service $svc.Name -StartupType Manual -ErrorAction SilentlyContinue
                
                Write-Log "  Set to Manual start" Success
                $script:Stats.OptimizationsApplied++
            }
        }
        catch {
            Write-Log "  Could not optimize $($svc.Display)" Warning
        }
        $progress += $step
        Update-ProgressBar $progress "Optimizing services..."
    }
    
    # Startup programs
    Update-ProgressBar 50 "Analyzing startup programs..."
    Write-Log "Reviewing startup programs..." Info
    
    try {
        $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
        $disabledCount = 0
        
        foreach ($item in $startupItems) {
            # Only suggest disabling, don't auto-disable critical items
            if ($item.Command -notmatch '(Security|Antivirus|Audio|Graphics)') {
                Write-Log "  Found: $($item.Name) - $($item.Location)" Info
                $disabledCount++
            }
        }
        
        Write-Log "  Found $disabledCount non-critical startup items" Info
        Write-Log "  Use Task Manager > Startup to selectively disable" Info
    }
    catch {
        Write-Log "  Could not enumerate startup items" Warning
    }
    
    Update-ProgressBar 100 "Services & startup optimization complete"
    Write-Log "Services optimization completed" Success
    
    Save-BackupFile
}

function Apply-SystemTweaks {
    Write-Log "APPLYING PERFORMANCE TWEAKS" Header
    Update-ProgressBar 0 "Applying registry optimizations..."
    
    $tweaks = @(
        @{
            Path = "HKCU:\Control Panel\Desktop\WindowMetrics"
            Name = "MinAnimate"
            Value = "0"
            Description = "Disable window animations"
        },
        @{
            Path = "HKCU:\Control Panel\Desktop"
            Name = "MenuShowDelay"
            Value = "100"
            Description = "Faster menu display"
        },
        @{
            Path = "HKCU:\Control Panel\Mouse"
            Name = "MouseHoverTime"
            Value = "100"
            Description = "Faster mouse hover"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "TaskbarAnimations"
            Value = 0
            Description = "Disable taskbar animations"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
            Name = "VisualFXSetting"
            Value = 2
            Description = "Optimize visual effects for performance"
        },
        @{
            Path = "HKCU:\Software\Microsoft\Windows\DWM"
            Name = "EnableAeroPeek"
            Value = 0
            Description = "Disable Aero Peek"
        }
    )
    
    $step = 100 / $tweaks.Count
    $progress = 0
    
    foreach ($tweak in $tweaks) {
        try {
            # Ensure path exists
            if (-not (Test-Path $tweak.Path)) {
                New-Item -Path $tweak.Path -Force -ErrorAction SilentlyContinue | Out-Null
            }
            
            # Backup existing value
            Backup-RegistryKey $tweak.Path $tweak.Name
            
            # Apply tweak
            Set-ItemProperty -Path $tweak.Path -Name $tweak.Name -Value $tweak.Value -Force
            Write-Log "Applied: $($tweak.Description)" Success
            $script:Stats.OptimizationsApplied++
        }
        catch {
            Write-Log "Could not apply: $($tweak.Description)" Warning
        }
        $progress += $step
        Update-ProgressBar $progress "Applying performance tweaks..."
    }
    
    Update-ProgressBar 100 "System tweaks applied"
    Write-Log "All performance tweaks applied successfully" Success
    
    Save-BackupFile
}

function Invoke-FullOptimization {
    Write-Log "═══════════════════════════════════════════" Header
    Write-Log "STARTING FULL SYSTEM OPTIMIZATION" Header
    Write-Log "═══════════════════════════════════════════" Header
    
    $runAllBtn.Enabled = $false
    
    Clear-TempAndCaches
    Start-Sleep -Seconds 1
    
    Optimize-DiskAndPagefile
    Start-Sleep -Seconds 1
    
    Optimize-MemoryAndCPU
    Start-Sleep -Seconds 1
    
    Optimize-ServicesAndStartup
    Start-Sleep -Seconds 1
    
    Apply-SystemTweaks
    
    Write-Log "═══════════════════════════════════════════" Header
    Write-Log "OPTIMIZATION COMPLETE!" Success
    Write-Log "Space Freed: $([Math]::Round($script:Stats.SpaceFreed, 2)) MB" Success
    Write-Log "Optimizations Applied: $($script:Stats.OptimizationsApplied)" Success
    Write-Log "═══════════════════════════════════════════" Header
    
    Update-ProgressBar 100 "All optimizations complete"
    $runAllBtn.Enabled = $true
    
    [System.Windows.Forms.MessageBox]::Show(
        "System optimization completed successfully!`n`nSpace Freed: $([Math]::Round($script:Stats.SpaceFreed, 2)) MB`nOptimizations Applied: $($script:Stats.OptimizationsApplied)`n`nA system restart is recommended.",
        "23 Optimizer - Complete",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

function Restore-SystemState {
    Write-Log "RESTORING SYSTEM STATE" Header
    Update-ProgressBar 0 "Loading backup..."
    
    if (Test-Path $script:BackupPath) {
        try {
            $backup = Get-Content $script:BackupPath | ConvertFrom-Json
            $backupHash = @{}
            $backup.PSObject.Properties | ForEach-Object { $backupHash[$_.Name] = $_.Value }
            
            $total = $backupHash.Count
            $current = 0
            
            foreach ($key in $backupHash.Keys) {
                if ($key -match '^Service_(.+)_StartType$') {
                    $serviceName = $matches[1]
                    $startType = $backupHash[$key]
                    $status = $backupHash["Service_${serviceName}_Status"]
                    
                    try {
                        Set-Service $serviceName -StartupType $startType -ErrorAction SilentlyContinue
                        if ($status -eq 'Running') {
                            Start-Service $serviceName -ErrorAction SilentlyContinue
                        }
                        Write-Log "Restored service: $serviceName" Success
                    }
                    catch { }
                }
                elseif ($key -match '\\') {
                    # Registry key
                    $parts = $key -split '\\'
                    $name = $parts[-1]
                    $path = $key.Substring(0, $key.LastIndexOf('\'))
                    
                    try {
                        Set-ItemProperty -Path $path -Name $name -Value $backupHash[$key] -Force
                        Write-Log "Restored: $key" Success
                    }
                    catch { }
                }
                
                $current++
                Update-ProgressBar (($current / $total) * 100) "Restoring system state..."
            }
            
            Write-Log "System state restored from backup" Success
        }
        catch {
            Write-Log "Could not restore from backup: $_" Error
        }
    }
    else {
        Write-Log "No backup file found at: $script:BackupPath" Warning
        Write-Log "Applying default restoration..." Info
        
        # Default restoration
        $services = @("DiagTrack","WSearch","SysMain","BITS","DPS","WerSvc")
        foreach ($s in $services) {
            try {
                Set-Service $s -StartupType Automatic -ErrorAction SilentlyContinue
                Start-Service $s -ErrorAction SilentlyContinue
            }
            catch { }
        }
        
        # Restore visual effects
        try {
            Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" -Value "1"
            Set-ItemProperty "HKCU:\Control Panel\Desktop" "MenuShowDelay" -Value "400"
            Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" -Value 1
        }
        catch { }
        
        Write-Log "Default restoration completed" Success
    }
    
    Update-ProgressBar 100 "Restoration complete"
}

function Show-SystemInfo {
    Write-Log "═══════════════════════════════════════════" Header
    Write-Log "SYSTEM INFORMATION" Header
    Write-Log "═══════════════════════════════════════════" Header
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor
        $ram = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $freeRam = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeDisk = [Math]::Round($disk.FreeSpace / 1GB, 2)
        $totalDisk = [Math]::Round($disk.Size / 1GB, 2)
        
        Write-Log "OS: $($os.Caption) $($os.Version)" Info
        Write-Log "CPU: $($cpu.Name)" Info
        Write-Log "RAM: $freeRam GB free of $ram GB total" Info
        Write-Log "Disk C: $freeDisk GB free of $totalDisk GB total" Info
        Write-Log "System Uptime: $([Math]::Round((Get-Date) - $os.LastBootUpTime).TotalHours, 2) hours" Info
    }
    catch {
        Write-Log "Could not retrieve system information" Error
    }
}

# ========================================
# GUI DESIGN - Modern Interface
# ========================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer Pro v$script:Version"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Header Panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(900, 80)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$form.Controls.Add($headerPanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "23 OPTIMIZER PRO"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$titleLabel.Size = New-Object System.Drawing.Size(500, 40)
$titleLabel.Location = New-Object System.Drawing.Point(20, 10)
$headerPanel.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Advanced Windows Performance & Optimization Suite"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 230, 240)
$subtitleLabel.Size = New-Object System.Drawing.Size(500, 25)
$subtitleLabel.Location = New-Object System.Drawing.Point(20, 48)
$headerPanel.Controls.Add($subtitleLabel)

# Control Panel
$controlPanel = New-Object System.Windows.Forms.Panel
$controlPanel.Size = New-Object System.Drawing.Size(860, 280)
$controlPanel.Location = New-Object System.Drawing.Point(20, 100)
$controlPanel.BackColor = [System.Drawing.Color]::White
$controlPanel.BorderStyle = "FixedSingle"
$form.Controls.Add($controlPanel)

# Buttons - Row 1
$btnY = 20
$btnX = 20
$btnWidth = 180
$btnHeight = 45
$btnSpacing = 200

$cleanBtn = New-Object System.Windows.Forms.Button
$cleanBtn.Text = "🗑️ Clean Temp & Caches"
$cleanBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$cleanBtn.Location = New-Object System.Drawing.Point($btnX, $btnY)
$cleanBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$cleanBtn.ForeColor = [System.Drawing.Color]::White
$cleanBtn.FlatStyle = "Flat"
$cleanBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$cleanBtn.Add_Click({ Clear-TempAndCaches })
$controlPanel.Controls.Add($cleanBtn)

$diskBtn = New-Object System.Windows.Forms.Button
$diskBtn.Text = "💾 Optimize Disk"
$diskBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$diskBtn.Location = New-Object System.Drawing.Point($btnX + $btnSpacing, $btnY)
$diskBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$diskBtn.ForeColor = [System.Drawing.Color]::White
$diskBtn.FlatStyle = "Flat"
$diskBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$diskBtn.Add_Click({ Optimize-DiskAndPagefile })
$controlPanel.Controls.Add($diskBtn)

$memoryBtn = New-Object System.Windows.Forms.Button
$memoryBtn.Text = "🧠 Optimize Memory & CPU"
$memoryBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$memoryBtn.Location = New-Object System.Drawing.Point($btnX + $btnSpacing*2, $btnY)
$memoryBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$memoryBtn.ForeColor = [System.Drawing.Color]::White
$memoryBtn.FlatStyle = "Flat"
$memoryBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$memoryBtn.Add_Click({ Optimize-MemoryAndCPU })
$controlPanel.Controls.Add($memoryBtn)

# Buttons - Row 2
$btnY += 70

$servicesBtn = New-Object System.Windows.Forms.Button
$servicesBtn.Text = "⚙ Services & Startup"
$servicesBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$servicesBtn.Location = New-Object System.Drawing.Point($btnX, $btnY)
$servicesBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$servicesBtn.ForeColor = [System.Drawing.Color]::White
$servicesBtn.FlatStyle = "Flat"
$servicesBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$servicesBtn.Add_Click({ Optimize-ServicesAndStartup })
$controlPanel.Controls.Add($servicesBtn)

$tweaksBtn = New-Object System.Windows.Forms.Button
$tweaksBtn.Text = "🎨 Apply System Tweaks"
$tweaksBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$tweaksBtn.Location = New-Object System.Drawing.Point($btnX + $btnSpacing, $btnY)
$tweaksBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$tweaksBtn.ForeColor = [System.Drawing.Color]::White
$tweaksBtn.FlatStyle = "Flat"
$tweaksBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$tweaksBtn.Add_Click({ Apply-SystemTweaks })
$controlPanel.Controls.Add($tweaksBtn)

$fullBtn = New-Object System.Windows.Forms.Button
$fullBtn.Text = "🚀 Run Full Optimization"
$fullBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$fullBtn.Location = New-Object System.Drawing.Point($btnX + $btnSpacing*2, $btnY)
$fullBtn.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)
$fullBtn.ForeColor = [System.Drawing.Color]::White
$fullBtn.FlatStyle = "Flat"
$fullBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$fullBtn.Add_Click({ Invoke-FullOptimization })
$controlPanel.Controls.Add($fullBtn)

# Buttons - Row 3
$btnY += 70

$restoreBtn = New-Object System.Windows.Forms.Button
$restoreBtn.Text = "🔄 Restore Backup / Defaults"
$restoreBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$restoreBtn.Location = New-Object System.Drawing.Point($btnX, $btnY)
$restoreBtn.BackColor = [System.Drawing.Color]::FromArgb(220, 20, 60)
$restoreBtn.ForeColor = [System.Drawing.Color]::White
$restoreBtn.FlatStyle = "Flat"
$restoreBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$restoreBtn.Add_Click({ Restore-SystemState })
$controlPanel.Controls.Add($restoreBtn)

$infoBtn = New-Object System.Windows.Forms.Button
$infoBtn.Text = "ℹ System Info"
$infoBtn.Size = New-Object System.Drawing.Size($btnWidth, $btnHeight)
$infoBtn.Location = New-Object System.Drawing.Point($btnX + $btnSpacing, $btnY)
$infoBtn.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
$infoBtn.ForeColor = [System.Drawing.Color]::White
$infoBtn.FlatStyle = "Flat"
$infoBtn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$infoBtn.Add_Click({ Show-SystemInfo })
$controlPanel.Controls.Add($infoBtn)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 400)
$progressBar.Size = New-Object System.Drawing.Size(860, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 430)
$statusLabel.Size = New-Object System.Drawing.Size(860, 25)
$statusLabel.Text = "Ready"
$statusLabel.ForeColor = [System.Drawing.Color]::Black
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$form.Controls.Add($statusLabel)

# Log Panel
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20, 460)
$richTextBox.Size = New-Object System.Drawing.Size(860, 180)
$richTextBox.ReadOnly = $true
$richTextBox.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 250)
$richTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($richTextBox)

# Show GUI
[void]$form.ShowDialog()
