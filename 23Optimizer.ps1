#Requires -RunAsAdministrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:Version = "2.0.0"
$script:Stats = @{
    SpaceFreed = 0
    OptimizationsApplied = 0
}

# --- GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer Pro v$script:Version"
$form.Size = New-Object System.Drawing.Size(900,700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240,240,245)
$form.Font = New-Object System.Drawing.Font("Segoe UI",9)

# Progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,400)
$progressBar.Size = New-Object System.Drawing.Size(860,25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100
$form.Controls.Add($progressBar)

# Status Label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20,430)
$statusLabel.Size = New-Object System.Drawing.Size(860,25)
$statusLabel.Text = "Ready"
$statusLabel.ForeColor = [System.Drawing.Color]::Black
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI",9,[System.Drawing.FontStyle]::Italic)
$form.Controls.Add($statusLabel)

# Log box
$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20,460)
$richTextBox.Size = New-Object System.Drawing.Size(860,180)
$richTextBox.ReadOnly = $true
$richTextBox.BackColor = [System.Drawing.Color]::FromArgb(245,245,250)
$richTextBox.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($richTextBox)

# --- Logging & progress functions ---
function Write-Log {
    param([string]$Message,[string]$Level="Info")
    if ($richTextBox) {
        $richTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $Message`r`n")
        $richTextBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Update-ProgressBar {
    param([int]$Value,[string]$Status="")
    if ($progressBar) { $progressBar.Value = [Math]::Min($Value,100) }
    if ($Status) { $statusLabel.Text = $Status }
    [System.Windows.Forms.Application]::DoEvents()
}

# --- Dummy optimizer functions ---
function Clear-TempAndCaches { Write-Log "Cleaning temp files..."; Start-Sleep -Milliseconds 500; Update-ProgressBar 25 "Temp cleaned"; $script:Stats.SpaceFreed += 100; $script:Stats.OptimizationsApplied++ }
function Optimize-DiskAndPagefile { Write-Log "Optimizing disk..."; Start-Sleep -Milliseconds 500; Update-ProgressBar 50 "Disk optimized"; $script:Stats.OptimizationsApplied++ }
function Optimize-MemoryAndCPU { Write-Log "Optimizing memory & CPU..."; Start-Sleep -Milliseconds 500; Update-ProgressBar 75 "Memory optimized"; $script:Stats.OptimizationsApplied++ }
function Apply-SystemTweaks { Write-Log "Applying tweaks..."; Start-Sleep -Milliseconds 500; Update-ProgressBar 100 "Tweaks applied"; $script:Stats.OptimizationsApplied++ }

function Invoke-FullOptimization {
    $fullBtn.Enabled = $false
    Clear-TempAndCaches
    Optimize-DiskAndPagefile
    Optimize-MemoryAndCPU
    Apply-SystemTweaks
    Write-Log "Optimization complete! Space freed: $($script:Stats.SpaceFreed) MB"
    $fullBtn.Enabled = $true
}

# --- Buttons ---
$fullBtn = New-Object System.Windows.Forms.Button
$fullBtn.Text = "🚀 Run Full Optimization"
$fullBtn.Size = New-Object System.Drawing.Size(180,45)
$fullBtn.Location = New-Object System.Drawing.Point(20,20)
$fullBtn.BackColor = [System.Drawing.Color]::FromArgb(34,139,34)
$fullBtn.ForeColor = [System.Drawing.Color]::White
$fullBtn.FlatStyle = "Flat"
$fullBtn.Add_Click({ Invoke-FullOptimization })
$form.Controls.Add($fullBtn)

# --- Show GUI ---
[void]$form.ShowDialog()
