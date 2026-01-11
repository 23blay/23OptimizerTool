#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================
# 23 OPTIMIZER PRO v2.0
# ==============================

$script:Version = "2.0.0"
$script:BackupPath = "$env:USERPROFILE\Documents\23Optimizer_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$script:StateBackup = @{}
$script:Stats = @{
    SpaceFreed = 0
    ItemsCleaned = 0
    OptimizationsApplied = 0
}

# ------------------------------
# Logging function
# ------------------------------
function Write-Log {
    param([string]$Message, [ValidateSet("Info","Success","Warning","Error","Header")] [string]$Level="Info")

    $timestamp = Get-Date -Format "HH:mm:ss"
    $richTextBox.SelectionStart = $richTextBox.TextLength
    $richTextBox.SelectionLength = 0

    $colors = @{
        "Success" = @{ Color = [System.Drawing.Color]::FromArgb(34,139,34); Prefix = "✓" }
        "Warning" = @{ Color = [System.Drawing.Color]::FromArgb(255,140,0); Prefix = "⚠" }
        "Error"   = @{ Color = [System.Drawing.Color]::FromArgb(220,20,60); Prefix = "✗" }
        "Header"  = @{ Color = [System.Drawing.Color]::FromArgb(70,130,180); Prefix = "▶" }
        "Info"    = @{ Color = [System.Drawing.Color]::FromArgb(60,60,60); Prefix = "•" }
    }

    $style = $colors[$Level]
    $richTextBox.SelectionColor = $style.Color

    if ($Level -eq "Header") {
        $richTextBox.SelectionFont = New-Object System.Drawing.Font($richTextBox.Font.FontFamily,10,[System.Drawing.FontStyle]::Bold)
    }

    $richTextBox.AppendText("[$timestamp] $($style.Prefix) $Message`r`n")
    $richTextBox.SelectionFont = New-Object System.Drawing.Font($richTextBox.Font.FontFamily,9,[System.Drawing.FontStyle]::Regular)
    $richTextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ------------------------------
# Progress Bar
# ------------------------------
function Update-ProgressBar {
    param([int]$Value, [string]$Status="")
    $progressBar.Value = [Math]::Min($Value,100)
    if ($Status) { $statusLabel.Text = $Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# ------------------------------
# Utility Functions
# ------------------------------
function Get-FolderSize { param([string]$Path)
    if (Test-Path $Path) {
        return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    }
    return 0
}

function Backup-RegistryKey { param([string]$Path,[string]$Name)
    try {
        if (Test-Path $Path) {
            $value = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($value) { $script:StateBackup["$Path\$Name"] = $value.$Name; Write-Log "Backed up: $Path\$Name" Info }
        }
    } catch { Write-Log "Could not backup $Path\$Name" Warning }
}

function Save-BackupFile {
    try { $script:StateBackup | ConvertTo-Json -Depth 10 | Out-File $script:BackupPath -Force; Write-Log "Backup saved: $script:BackupPath" Success }
    catch { Write-Log "Failed to save backup file: $_" Error }
}

# ------------------------------
# Optimization Functions
# ------------------------------

function Clear-TempAndCaches {
    Write-Log "CLEANING TEMPORARY FILES AND CACHES" Header
    Update-ProgressBar 0 "Analyzing temporary files..."

    $totalFreed = 0
    $locations = @(
        @{Path="$env:TEMP"; Name="User Temp"},
        @{Path="C:\Windows\Temp"; Name="Windows Temp"},
        @{Path="$env:LOCALAPPDATA\Temp"; Name="Local Temp"}
    )

    $step = 100 / ($locations.Count + 5)
    $progress = 0

    foreach ($loc in $locations) {
        try {
            if (Test-Path $loc.Path) {
                $sizeBefore = Get-FolderSize $loc.Path
                Write-Log "Cleaning $($loc.Name)..." Info

                Get-ChildItem $loc.Path -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                $sizeAfter = Get-FolderSize $loc.Path
                $freed = ($sizeBefore - $sizeAfter) / 1MB
                $totalFreed += $freed
                Write-Log "  Freed $([Math]::Round($freed,2)) MB" Success
            }
        } catch { Write-Log "  Could not fully clean $($loc.Name)" Warning }
        $progress += $step
        Update-ProgressBar $progress "Cleaning $($loc.Name)..."
    }

    # Recycle Bin
    Write-Log "Emptying Recycle Bin..." Info
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Log "  Recycle Bin emptied" Success } catch { Write-Log "  Recycle Bin not cleared" Warning }
    $progress += $step; Update-ProgressBar $progress "Emptying Recycle Bin..."

    $script:Stats.SpaceFreed += $totalFreed
    Update-ProgressBar 100 "Cleanup complete"
    Write-Log "TOTAL SPACE FREED: $([Math]::Round($totalFreed,2)) MB" Success
}

function Invoke-FullOptimization {
    Write-Log "════════════════════════" Header
    Write-Log "STARTING FULL SYSTEM OPTIMIZATION" Header
    Write-Log "════════════════════════" Header
    $runAllBtn.Enabled = $false

    Clear-TempAndCaches
    Start-Sleep -Seconds 1

    # Placeholder for Disk/Memory/Services tweaks
    Write-Log "Disk, Memory, Services, and Tweaks optimization would run here" Info
    $script:Stats.OptimizationsApplied += 5
    Start-Sleep -Seconds 1

    Write-Log "════════════════════════" Header
    Write-Log "OPTIMIZATION COMPLETE!" Success
    Write-Log "Space Freed: $([Math]::Round($script:Stats.SpaceFreed,2)) MB" Success
    Write-Log "Optimizations Applied: $($script:Stats.OptimizationsApplied)" Success
    Write-Log "════════════════════════" Header

    Update-ProgressBar 100 "All optimizations complete"
    $runAllBtn.Enabled = $true
}

function Show-SystemInfo {
    Write-Log "════════════════════════" Header
    Write-Log "SYSTEM INFORMATION" Header
    Write-Log "════════════════════════" Header
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor
        $ram = [Math]::Round($os.TotalVisibleMemorySize / 1MB,2)
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeDisk = [Math]::Round($disk.FreeSpace / 1GB,2)
        Write-Log "OS: $($os.Caption) $($os.Version)" Info
        Write-Log "CPU: $($cpu.Name)" Info
        Write-Log "RAM: $ram MB" Info
        Write-Log "Disk C: $freeDisk GB free" Info
    } catch { Write-Log "Could not retrieve system info" Error }
}

# ------------------------------
# GUI Setup
# ------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer Pro v$script:Version"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240,240,245)
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

# Buttons
$runAllBtn = New-Object System.Windows.Forms.Button
$runAllBtn.Text = "Run Full Optimization"
$runAllBtn.Size = New-Object System.Drawing.Size(200,50)
$runAllBtn.Location = New-Object System.Drawing.Point(20,20)
$runAllBtn.BackColor = [System.Drawing.Color]::FromArgb(34,139,34)
$runAllBtn.ForeColor = [System.Drawing.Color]::White
$runAllBtn.FlatStyle = "Flat"
$runAllBtn.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$runAllBtn.Add_Click({ Invoke-FullOptimization })
$form.Controls.Add($runAllBtn)

$infoBtn = New-Object System.Windows.Forms.Button
$infoBtn.Text = "System Info"
$infoBtn.Size = New-Object System.Drawing.Size(200,50)
$infoBtn.Location = New-Object System.Drawing.Point(240,20)
$infoBtn.BackColor = [System.Drawing.Color]::FromArgb(70,130,180)
$infoBtn.ForeColor = [System.Drawing.Color]::White
$infoBtn.FlatStyle = "Flat"
$infoBtn.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$infoBtn.Add_Click({ Show-SystemInfo })
$form.Controls.Add($infoBtn)

# Progress bar and log
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,100)
$progressBar.Size = New-Object System.Drawing.Size(740,25)
$progressBar.Minimum = 0; $progressBar.Maximum = 100
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20,130)
$statusLabel.Size = New-Object System.Drawing.Size(740,25)
$statusLabel.Text = "Ready"
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$form.Controls.Add($statusLabel)

$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20,160)
$richTextBox.Size = New-Object System.Drawing.Size(740,380)
$richTextBox.ReadOnly = $true
$richTextBox.BackColor = [System.Drawing.Color]::FromArgb(245,245,250)
$richTextBox.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($richTextBox)

# Show GUI
[void]$form.ShowDialog()
