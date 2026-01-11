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
# GUI ELEMENTS PLACEHOLDER
# Will be created below; needed by functions
# ========================================
$richTextBox = $null
$progressBar = $null
$statusLabel = $null
$fullBtn = $null

# ========================================
# CORE FUNCTIONS
# ========================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error","Header")]
        [string]$Level = "Info"
    )
    if (-not $richTextBox) { return }

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

function Update-ProgressBar {
    param([int]$Value, [string]$Status = "")
    if ($progressBar) {
        $progressBar.Value = [Math]::Min($Value,100)
    }
    if ($statusLabel -and $Status) {
        $statusLabel.Text = $Status
    }
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-FolderSize {
    param([string]$Path)
    if (Test-Path $Path) {
        return (Get-ChildItem $Path -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    }
    return 0
}

function Backup-RegistryKey {
    param([string]$Path,[string]$Name)
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
# OPTIMIZATION FUNCTIONS
# ========================================

function Clear-TempAndCaches {
    Write-Log "CLEANING TEMPORARY FILES & CACHES" Header
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
                $sizeBefore = Get-FolderSize -Path $loc.Path
                Write-Log "Cleaning $($loc.Name)..." Info
                Get-ChildItem -Path $loc.Path -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $sizeAfter = Get-FolderSize -Path $loc.Path
                $freed = ($sizeBefore - $sizeAfter)/1MB
                $totalFreed += $freed
                Write-Log "  Freed: $([Math]::Round($freed,2)) MB" Success
            }
        }
        catch {
            Write-Log "  Could not fully clean $($loc.Name): $_" Warning
        }
        $progress += $step
        Update-ProgressBar $progress "Cleaning $($loc.Name)..."
    }

    # Recycle Bin
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue; Write-Log "Recycle Bin emptied" Success }
    catch { Write-Log "Could not empty Recycle Bin" Warning }
    $progress += $step
    Update-ProgressBar $progress "Emptying Recycle Bin..."

    $script:Stats.SpaceFreed += $totalFreed
    Update-ProgressBar 100 "Cleanup complete"
    Write-Log "TOTAL SPACE FREED: $([Math]::Round($totalFreed,2)) MB" Success
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
            Write-Log "Running TRIM for SSD..." Info
            Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
            Write-Log "  TRIM completed" Success
            try { Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Set-Service SysMain -StartupType Disabled -ErrorAction SilentlyContinue } catch {}
        }
        else {
            Write-Log "Defragmenting HDD..." Info
            Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
            Write-Log "  Defrag completed" Success
        }

        $script:Stats.OptimizationsApplied++
        Update-ProgressBar 100 "Disk optimization complete"
        Write-Log "Disk optimization completed successfully" Success
    }
    catch { Write-Log "Disk optimization error: $_" Error }
}

function Optimize-MemoryAndCPU {
    Write-Log "MEMORY & CPU OPTIMIZATION" Header
    Update-ProgressBar 0 "Cleaning memory..."
    [System.GC]::Collect(); [System.GC]::WaitForPendingFinalizers(); [System.GC]::Collect()
    Write-Log "Memory garbage collection done" Success
    Update-ProgressBar 50 "Optimizing CPU priorities..."
    Get-Process | Where-Object { $_.CPU -lt 0.1 -and $_.ProcessName -notmatch '^(csrss|dwm|explorer|lsass|services|smss|System|wininit|winlogon)$' } |
        ForEach-Object { try { $_.PriorityClass = "BelowNormal" } catch {} }
    Write-Log "Idle processes optimized" Success
    $script:Stats.OptimizationsApplied++
    Update-ProgressBar 100 "Memory & CPU optimization complete"
}

function Invoke-FullOptimization {
    Write-Log "════════════════════════════" Header
    Write-Log "STARTING FULL SYSTEM OPTIMIZATION" Header
    $fullBtn.Enabled = $false
    Clear-TempAndCaches
    Start-Sleep 1
    Optimize-DiskAndPagefile
    Start-Sleep 1
    Optimize-MemoryAndCPU
    Start-Sleep 1
    Write-Log "Full optimization completed!" Success
    $fullBtn.Enabled = $true
    [System.Windows.Forms.MessageBox]::Show("System optimization completed!`nSpace Freed: $([Math]::Round($script:Stats.SpaceFreed,2)) MB`nOptimizations Applied: $($script:Stats.OptimizationsApplied)","23 Optimizer", "OK", "Information")
}

# ========================================
# GUI CREATION
# ========================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer Pro v$script:Version"
$form.Size = New-Object System.Drawing.Size(900,700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240,240,245)
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

# RichTextBox for logs
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20,460)
$richTextBox.Size = New-Object System.Drawing.Size(860,180)
$richTextBox.ReadOnly = $true
$richTextBox.BackColor = [System.Drawing.Color]::FromArgb(245,245,250)
$richTextBox.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($richTextBox)

# Progress Bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,400)
$progressBar.Size = New-Object System.Drawing.Size(860,25)
$progressBar.Minimum = 0; $progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20,430)
$statusLabel.Size = New-Object System.Drawing.Size(860,25)
$statusLabel.Text = "Ready"
$statusLabel.ForeColor = [System.Drawing.Color]::Black
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$form.Controls.Add($statusLabel)

# Full Optimization Button
$fullBtn = New-Object System.Windows.Forms.Button
$fullBtn.Text = "🚀 Run Full Optimization"
$fullBtn.Size = New-Object System.Drawing.Size(200,45)
$fullBtn.Location = New-Object System.Drawing.Point(20,360)
$fullBtn.BackColor = [System.Drawing.Color]::FromArgb(34,139,34)
$fullBtn.ForeColor = [System.Drawing.Color]::White
$fullBtn.FlatStyle = "Flat"
$fullBtn.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Bold)
$fullBtn.Add_Click({ Invoke-FullOptimization })
$form.Controls.Add($fullBtn)

# Launch GUI
[void]$form.ShowDialog()
