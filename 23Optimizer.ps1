# Requires admin
Add-Type -AssemblyName System.Windows.Forms

# ------------------------------
# Stats
# ------------------------------
$stats = @{
    SpaceFreed = 0
    OptimizationsApplied = 0
}

# ------------------------------
# Functions
# ------------------------------
function Write-Stats {
    $spaceLabel.Text = "Space Freed: $([Math]::Round($stats.SpaceFreed,2)) MB"
    $optLabel.Text = "Optimizations Applied: $($stats.OptimizationsApplied)"
}

function Clear-TempFiles {
    $paths = @("$env:TEMP","C:\Windows\Temp")
    $totalFreed = 0
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $before = (Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
            Get-ChildItem $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $after = (Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1MB
            $totalFreed += ($before - $after)
        }
    }
    $stats.SpaceFreed += $totalFreed
    $stats.OptimizationsApplied++
    Write-Stats
}

function Optimize-Memory {
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    $stats.OptimizationsApplied++
    Write-Stats
}

function Optimize-Disk {
    $drives = Get-PSDrive -PSProvider 'FileSystem' | Where-Object {$_.Name -eq "C"}
    foreach ($d in $drives) {
        try { Optimize-Volume -DriveLetter $d.Name -Defrag -ErrorAction SilentlyContinue } catch {}
    }
    $stats.OptimizationsApplied++
    Write-Stats
}

function Apply-SafeTweaks {
    # Safe visual and performance tweaks
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "100"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
        $stats.OptimizationsApplied++
        Write-Stats
    } catch {}
}

# ------------------------------
# GUI
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer Pro - Safe Max"
$form.Size = New-Object System.Drawing.Size(350,250)
$form.StartPosition = "CenterScreen"

# Labels
$spaceLabel = New-Object System.Windows.Forms.Label
$spaceLabel.Location = New-Object System.Drawing.Point(20,20)
$spaceLabel.Size = New-Object System.Drawing.Size(300,25)
$spaceLabel.Text = "Space Freed: 0 MB"
$form.Controls.Add($spaceLabel)

$optLabel = New-Object System.Windows.Forms.Label
$optLabel.Location = New-Object System.Drawing.Point(20,50)
$optLabel.Size = New-Object System.Drawing.Size(300,25)
$optLabel.Text = "Optimizations Applied: 0"
$form.Controls.Add($optLabel)

# Buttons
$btnY = 90
$btnHeight = 30
$btnWidth = 280

$btnTemp = New-Object System.Windows.Forms.Button
$btnTemp.Text = "Clear Temp Files"
$btnTemp.Location = New-Object System.Drawing.Point(20,$btnY)
$btnTemp.Size = New-Object System.Drawing.Size($btnWidth,$btnHeight)
$btnTemp.Add_Click({ Clear-TempFiles })
$form.Controls.Add($btnTemp)

$btnY += 40
$btnMemory = New-Object System.Windows.Forms.Button
$btnMemory.Text = "Optimize Memory"
$btnMemory.Location = New-Object System.Drawing.Point(20,$btnY)
$btnMemory.Size = New-Object System.Drawing.Size($btnWidth,$btnHeight)
$btnMemory.Add_Click({ Optimize-Memory })
$form.Controls.Add($btnMemory)

$btnY += 40
$btnDisk = New-Object System.Windows.Forms.Button
$btnDisk.Text = "Optimize Disk"
$btnDisk.Location = New-Object System.Drawing.Point(20,$btnY)
$btnDisk.Size = New-Object System.Drawing.Size($btnWidth,$btnHeight)
$btnDisk.Add_Click({ Optimize-Disk })
$form.Controls.Add($btnDisk)

$btnY += 40
$btnTweaks = New-Object System.Windows.Forms.Button
$btnTweaks.Text = "Apply Safe Tweaks"
$btnTweaks.Location = New-Object System.Drawing.Point(20,$btnY)
$btnTweaks.Size = New-Object System.Drawing.Size($btnWidth,$btnHeight)
$btnTweaks.Add_Click({ Apply-SafeTweaks })
$form.Controls.Add($btnTweaks)

# Show GUI
[void]$form.ShowDialog()
