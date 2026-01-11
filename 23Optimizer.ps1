# 23 Optimizer v5.2 - Fully Automated Ultimate PC Optimizer with Live RAM/CPU Optimization

function Write-Color {
    param([string]$Text, [ConsoleColor]$Color='White')
    $prev = $Host.UI.RawUI.ForegroundColor
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.ForegroundColor = $prev
}

function Show-Progress {
    param([string]$Activity,[int]$Percent)
    Write-Progress -Activity $Activity -PercentComplete $Percent
}

function Detect-SSD {
    $drives = Get-PhysicalDisk | Select-Object FriendlyName, MediaType
    return $drives | Where-Object {$_.MediaType -eq 'SSD'}
}

function Log-Action {
    param([string]$Message)
    $logPath = "$env:USERPROFILE\Desktop\23Optimizer_Log.txt"
    Add-Content -Path $logPath -Value ("[$(Get-Date -Format G)] $Message")
}

# ------------------------
# Cleanup Functions
# ------------------------
function Clear-Temp {
    Write-Color "Clearing Temp folders..." Cyan
    $paths = @("$env:temp","C:\Windows\Temp")
    foreach ($p in $paths) {
        if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue; Log-Action "Cleared $p" }
    }
}

function Clear-RecycleBin {
    Write-Color "Emptying Recycle Bin..." Cyan
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0xA).Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue; Log-Action "Removed Recycle Bin item: $($_.Path)" }
}

function Clear-Prefetch {
    Write-Color "Clearing Prefetch files..." Cyan
    $prefetch = "C:\Windows\Prefetch\*"
    Remove-Item $prefetch -Force -ErrorAction SilentlyContinue
    Log-Action "Cleared Prefetch"
}

function Clear-BrowserCache {
    Write-Color "Clearing browser caches..." Cyan
    $caches = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
        "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
    )
    foreach ($cache in $caches) {
        if (Test-Path $cache) { Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue; Log-Action "Cleared browser cache: $cache" }
    }
}

function Clear-WindowsUpdateCache {
    Write-Color "Cleaning Windows Update cache..." Cyan
    $wu = "C:\Windows\SoftwareDistribution\Download\*"
    if (Test-Path $wu) { Remove-Item $wu -Recurse -Force -ErrorAction SilentlyContinue; Log-Action "Cleared Windows Update cache" }
}

function Clear-Logs {
    Write-Color "Cleaning Windows log files..." Cyan
    $logs = @("C:\Windows\Logs\*","C:\Windows\System32\LogFiles\*")
    foreach ($l in $logs) { if (Test-Path $l) { Remove-Item $l -Recurse -Force -ErrorAction SilentlyContinue; Log-Action "Cleared logs: $l" } }
}

# ------------------------
# Optimization Functions
# ------------------------
function Optimize-Services {
    Write-Color "Optimizing background services..." Cyan
    $services = @("DiagTrack","WSearch","SysMain")
    foreach ($s in $services) {
        if ((Get-Service $s).Status -eq "Running") { Stop-Service $s -Force; Set-Service $s -StartupType Manual; Log-Action "Stopped service $s" }
    }
}

function Optimize-MemoryCPU {
    # Free memory
    [void][System.GC]::Collect()
    [void][System.GC]::WaitForPendingFinalizers()
    # Lower priority of idle processes
    Get-Process | Where-Object {$_.CPU -eq 0} | ForEach-Object { try { $_.PriorityClass = "BelowNormal" } catch {} }
    Log-Action "Optimized Memory & CPU"
}

function Optimize-Disk {
    $ssd = Detect-SSD
    if ($ssd) { Write-Color "SSD detected. Skipping defrag and pagefile tweaks." Yellow }
    else {
        Write-Color "HDD detected. Performing defrag and pagefile optimization..." Cyan
        Optimize-Volume -DriveLetter C -Defrag -Verbose
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles" -Value "C:\pagefile.sys 4096 8192"
        Log-Action "Disk and pagefile optimized"
    }
}

function Optimize-StartupApps {
    Write-Color "Optimizing startup applications..." Cyan
    Get-CimInstance Win32_StartupCommand | Where-Object {$_.User -ne $null} | ForEach-Object { try { $_ | Invoke-CimMethod -MethodName Disable; Log-Action "Disabled startup app: $($_.Name)" } catch {} }
}

function Apply-SystemTweaks {
    Write-Color "Applying system tweaks..." Cyan
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" -Value "0"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" "MenuShowDelay" -Value "100"
    Log-Action "Applied system tweaks"
}

function Revert-Changes {
    Write-Color "Reverting all changes..." Red
    $services = @("DiagTrack","WSearch","SysMain")
    foreach ($s in $services) { try { Set-Service $s -StartupType Automatic; Start-Service $s; Log-Action "Restored service $s" } catch {} }
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" -Value "1"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" "MenuShowDelay" -Value "400"
    Write-Color "All changes reverted!" Green
    Log-Action "Reverted all tweaks"
}

# ------------------------
# Live Monitoring & Periodic Optimization
# ------------------------
function Start-LiveOptimization {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        Clear-Host
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time'
        $ram = Get-Counter '\Memory\Available MBytes'
        Write-Color ("CPU Usage: {0:N1}%" -f $cpu.CounterSamples[0].CookedValue) Magenta
        Write-Color ("Available RAM: {0:N0} MB" -f $ram.CounterSamples[0].CookedValue) Magenta
        # Free RAM & optimize CPU every 10 seconds
        if ($timer.Elapsed.TotalSeconds -ge 10) {
            Optimize-MemoryCPU
            $timer.Restart()
        }
        Start-Sleep -Milliseconds 1000
    }
}

# ------------------------
# Fully Automated Execution
# ------------------------
Clear-Host
Write-Color "Starting 23 Optimizer - Fully Automated" Cyan

$steps = @(
    @{Func=Clear-Temp; Desc="Cleaning Temp folders"},
    @{Func=Clear-RecycleBin; Desc="Emptying Recycle Bin"},
    @{Func=Clear-Prefetch; Desc="Clearing Prefetch files"},
    @{Func=Clear-BrowserCache; Desc="Clearing Browser Caches"},
    @{Func=Clear-WindowsUpdateCache; Desc="Cleaning Windows Update cache"},
    @{Func=Clear-Logs; Desc="Cleaning Windows Logs"},
    @{Func=Optimize-Services; Desc="Optimizing Services"},
    @{Func=Optimize-MemoryCPU; Desc="Optimizing Memory & CPU"},
    @{Func=Optimize-Disk; Desc="Optimizing Disk"},
    @{Func=Optimize-StartupApps; Desc="Optimizing Startup Apps"},
    @{Func=Apply-SystemTweaks; Desc="Applying System Tweaks"}
)

$total = $steps.Count
for ($i=0; $i -lt $total; $i++) {
    $percent = [int](($i/$total)*100)
    Show-Progress $steps[$i].Desc $percent
    & $steps[$i].Func
}

Show-Progress "Optimization Complete!" 100
Write-Color "`nAll initial optimizations complete!" Green
Write-Color "Starting live RAM & CPU optimization. Press Ctrl+C to stop." Yellow

Start-LiveOptimization
