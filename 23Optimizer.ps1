# 23 Optimizer - Main Script
# Save this in same folder as 23Optimizer.bat

function Show-MainMenu {
    do {
        Clear-Host
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "            23 OPTIMIZER" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Quick Cleanup" -ForegroundColor Yellow
        Write-Host "2. Disk Optimization" -ForegroundColor Yellow
        Write-Host "3. Network Optimization" -ForegroundColor Yellow
        Write-Host "4. Performance Tweaks" -ForegroundColor Yellow
        Write-Host "5. Privacy Cleaner" -ForegroundColor Yellow
        Write-Host "6. System Information" -ForegroundColor Yellow
        Write-Host "7. Create Restore Point" -ForegroundColor Magenta
        Write-Host "8. Complete Optimization" -ForegroundColor Green
        Write-Host "0. Exit" -ForegroundColor Gray
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        
        $choice = Read-Host "Select option"
        
        switch ($choice) {
            '1' { Quick-Cleanup }
            '2' { Disk-Optimization }
            '3' { Network-Optimization }
            '4' { Performance-Tweaks }
            '5' { Privacy-Cleaner }
            '6' { System-Information }
            '7' { Create-RestorePoint }
            '8' { Complete-Optimization }
            '0' { return }
            default { Write-Host "Invalid selection!" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne '0')
}

function Quick-Cleanup {
    Write-Host "`n[QUICK CLEANUP]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[1/6] Cleaning Windows temp files..." -ForegroundColor Yellow
    Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[2/6] Cleaning user temp files..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[3/6] Cleaning prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[4/6] Emptying recycle bin..." -ForegroundColor Yellow
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    
    Write-Host "[5/6] Flushing DNS cache..." -ForegroundColor Yellow
    ipconfig /flushdns | Out-Null
    
    Write-Host "[6/6] Cleaning error reports..." -ForegroundColor Yellow
    Remove-Item -Path "$env:ProgramData\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n[✓] Quick cleanup completed!" -ForegroundColor Green
    Pause-Continue
}

function Disk-Optimization {
    Write-Host "`n[DISK OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[1/4] Analyzing disk type..." -ForegroundColor Yellow
    $disk = Get-PhysicalDisk | Select-Object -First 1
    
    if ($disk.MediaType -eq 'SSD') {
        Write-Host "   Detected: SSD" -ForegroundColor Gray
        Write-Host "[2/4] Running TRIM optimization..." -ForegroundColor Yellow
        Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
    } else {
        Write-Host "   Detected: HDD" -ForegroundColor Gray
        Write-Host "[2/4] Running defragmentation..." -ForegroundColor Yellow
        Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
    }
    
    Write-Host "[3/4] Cleaning up system files..." -ForegroundColor Yellow
    Start-Process cleanmgr -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden
    
    Write-Host "[4/4] Checking disk health..." -ForegroundColor Yellow
    chkdsk C: /scan | Out-Null
    
    Write-Host "`n[✓] Disk optimization completed!" -ForegroundColor Green
    Pause-Continue
}

function Network-Optimization {
    Write-Host "`n[NETWORK OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[1/5] Flushing DNS cache..." -ForegroundColor Yellow
    ipconfig /flushdns | Out-Null
    
    Write-Host "[2/5] Resetting TCP/IP stack..." -ForegroundColor Yellow
    netsh int ip reset | Out-Null
    
    Write-Host "[3/5] Resetting Winsock..." -ForegroundColor Yellow
    netsh winsock reset | Out-Null
    
    Write-Host "[4/5] Releasing IP address..." -ForegroundColor Yellow
    ipconfig /release | Out-Null
    Start-Sleep -Seconds 2
    
    Write-Host "[5/5] Renewing IP address..." -ForegroundColor Yellow
    ipconfig /renew | Out-Null
    
    Write-Host "`n[✓] Network optimization completed!" -ForegroundColor Green
    Write-Host "You may need to restart for all changes to take effect." -ForegroundColor Gray
    Pause-Continue
}

function Performance-Tweaks {
    Write-Host "`n[PERFORMANCE TWEAKS]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[1/5] Setting high performance power plan..." -ForegroundColor Yellow
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    
    Write-Host "[2/5] Disabling visual effects..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -ErrorAction SilentlyContinue
    
    Write-Host "[3/5] Optimizing for background services..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -ErrorAction SilentlyContinue
    
    Write-Host "[4/5] Disabling unnecessary animations..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -ErrorAction SilentlyContinue
    
    Write-Host "[5/5] Optimizing memory usage..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -ErrorAction SilentlyContinue
    
    Write-Host "`n[✓] Performance tweaks applied!" -ForegroundColor Green
    Write-Host "Restart recommended for best results." -ForegroundColor Gray
    Pause-Continue
}

function Privacy-Cleaner {
    Write-Host "`n[PRIVACY CLEANER]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "[1/6] Clearing recent files..." -ForegroundColor Yellow
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[2/6] Clearing run dialog history..." -ForegroundColor Yellow
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Name "*" -ErrorAction SilentlyContinue
    
    Write-Host "[3/6] Clearing Windows search history..." -ForegroundColor Yellow
    Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host "[4/6] Disabling telemetry..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Host "[5/6] Disabling Cortana..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -ErrorAction SilentlyContinue
    
    Write-Host "[6/6] Disabling Windows tips..." -ForegroundColor Yellow
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -ErrorAction SilentlyContinue
    
    Write-Host "`n[✓] Privacy cleanup completed!" -ForegroundColor Green
    Pause-Continue
}

function System-Information {
    Write-Host "`n[SYSTEM INFORMATION]" -ForegroundColor Cyan
    Write-Host ""
    
    # OS Info
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host "Operating System:" -ForegroundColor Yellow
    Write-Host "  $($os.Caption)" -ForegroundColor Gray
    Write-Host "  Version: $($os.Version)" -ForegroundColor Gray
    Write-Host "  Build: $($os.BuildNumber)" -ForegroundColor Gray
    Write-Host ""
    
    # CPU Info
    $cpu = Get-CimInstance Win32_Processor
    Write-Host "Processor:" -ForegroundColor Yellow
    Write-Host "  $($cpu.Name)" -ForegroundColor Gray
    Write-Host "  Cores: $($cpu.NumberOfCores)" -ForegroundColor Gray
    Write-Host "  Threads: $($cpu.NumberOfLogicalProcessors)" -ForegroundColor Gray
    Write-Host ""
    
    # RAM Info
    $ram = Get-CimInstance Win32_ComputerSystem
    $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    Write-Host "Memory:" -ForegroundColor Yellow
    Write-Host "  Total: ${totalRAM}GB" -ForegroundColor Gray
    Write-Host ""
    
    # Disk Info
    $disk = Get-PSDrive C
    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    $totalGB = [math]::Round(($disk.Free + $disk.Used) / 1GB, 2)
    Write-Host "Disk C:" -ForegroundColor Yellow
    Write-Host "  Total: ${totalGB}GB" -ForegroundColor Gray
    Write-Host "  Free: ${freeGB}GB" -ForegroundColor Gray
    Write-Host "  Used: $($totalGB - $freeGB)GB" -ForegroundColor Gray
    
    Pause-Continue
}

function Create-RestorePoint {
    Write-Host "`n[CREATE RESTORE POINT]" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Creating system restore point..." -ForegroundColor Yellow
    try {
        $description = "23 Optimizer Backup - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "`n[✓] Restore point created successfully!" -ForegroundColor Green
        Write-Host "Name: $description" -ForegroundColor Gray
    }
    catch {
        Write-Host "`n[!] Could not create restore point" -ForegroundColor Red
        Write-Host "Make sure System Protection is enabled:" -ForegroundColor Gray
        Write-Host "1. Right-click This PC → Properties" -ForegroundColor Gray
        Write-Host "2. System Protection → Configure" -ForegroundColor Gray
        Write-Host "3. Enable system protection" -ForegroundColor Gray
    }
    
    Pause-Continue
}

function Complete-Optimization {
    Write-Host "`n[COMPLETE OPTIMIZATION]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will run all optimization modules." -ForegroundColor Yellow
    Write-Host "Estimated time: 2-3 minutes" -ForegroundColor Gray
    Write-Host ""
    
    $confirm = Read-Host "Continue? (Y/N)"
    if ($confirm -ne 'Y' -and $confirm -ne 'y') { return }
    
    # Create restore point first
    Create-RestorePoint
    
    # Run all optimizations
    Write-Host "`nStarting complete optimization..." -ForegroundColor Yellow
    Write-Host ""
    
    Quick-Cleanup
    Disk-Optimization
    Network-Optimization
    Performance-Tweaks
    Privacy-Cleaner
    
    Write-Host "`n[✓] COMPLETE OPTIMIZATION FINISHED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Recommendations:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor Gray
    Write-Host "2. Check for Windows updates" -ForegroundColor Gray
    Write-Host "3. Run monthly for maintenance" -ForegroundColor Gray
    
    Pause-Continue
}

function Pause-Continue {
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

# ============================================
# MAIN EXECUTION
# ============================================

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       23 OPTIMIZER STARTING" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking system..." -ForegroundColor Yellow

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click and select 'Run as administrator'" -ForegroundColor Yellow
    Pause-Continue
    exit
}

Write-Host "[✓] Running as Administrator" -ForegroundColor Green

# Show main menu
Show-MainMenu

# Exit message
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    THANK YOU FOR USING 23 OPTIMIZER" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "For best results:" -ForegroundColor Yellow
Write-Host "• Restart your computer" -ForegroundColor Gray
Write-Host "• Run monthly for maintenance" -ForegroundColor Gray
Write-Host "• Keep Windows updated" -ForegroundColor Gray
Write-Host ""
Start-Sleep -Seconds 3