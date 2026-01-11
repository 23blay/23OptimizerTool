Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------
# FUNCTIONS
# ------------------------

function Log-Status {
    param([string]$Text, [string]$Color="Black")
    $richTextBox.SelectionStart = $richTextBox.TextLength
    $richTextBox.SelectionLength = 0
    switch ($Color) {
        "Green" { $richTextBox.SelectionColor = [System.Drawing.Color]::Green }
        "Yellow" { $richTextBox.SelectionColor = [System.Drawing.Color]::Orange }
        "Red" { $richTextBox.SelectionColor = [System.Drawing.Color]::Red }
        default { $richTextBox.SelectionColor = [System.Drawing.Color]::Black }
    }
    $richTextBox.AppendText("$Text`r`n")
    $richTextBox.ScrollToCaret()
}

function Clear-TempAndCaches {
    Log-Status "Cleaning Temp folders..." Yellow
    $paths = @("$env:TEMP","C:\Windows\Temp")
    foreach ($p in $paths) { if (Test-Path $p) { Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue } }
    
    Log-Status "Emptying Recycle Bin..." Yellow
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0xA).Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
    
    Log-Status "Clearing Prefetch..." Yellow
    if (Test-Path "C:\Windows\Prefetch") { Remove-Item "C:\Windows\Prefetch\*" -Force -ErrorAction SilentlyContinue }
    
    Log-Status "Clearing Browser Caches..." Yellow
    $caches = @(
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
        "$env:APPDATA\Mozilla\Firefox\Profiles\*\cache2\*"
    )
    foreach ($c in $caches) { if (Test-Path $c) { Remove-Item $c -Recurse -Force -ErrorAction SilentlyContinue } }

    Log-Status "[✓] Temp and cache cleanup complete" Green
}

function Optimize-DiskAndPagefile {
    Log-Status "Optimizing Disk & Pagefile..." Yellow
    $ssd = Get-PhysicalDisk | Where-Object MediaType -eq 'SSD'
    if ($ssd) {
        Log-Status "SSD detected: skipping defrag" Yellow
        Optimize-Volume -DriveLetter C -ReTrim -Verbose
    } else {
        Log-Status "HDD detected: performing defrag..." Yellow
        Optimize-Volume -DriveLetter C -Defrag -Verbose
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "PagingFiles" -Value "C:\pagefile.sys 4096 8192"
    }
    Log-Status "[✓] Disk & Pagefile optimization complete" Green
}

function Optimize-MemoryAndCPU {
    Log-Status "Optimizing Memory & CPU..." Yellow
    [void][System.GC]::Collect()
    [void][System.GC]::WaitForPendingFinalizers()
    Get-Process | Where-Object {$_.CPU -eq 0} | ForEach-Object { try { $_.PriorityClass = "BelowNormal" } catch {} }
    Log-Status "[✓] Memory & CPU optimization complete" Green
}

function Optimize-ServicesAndStartup {
    Log-Status "Optimizing Services & Startup Apps..." Yellow
    $services = @("DiagTrack","WSearch","SysMain")
    foreach ($s in $services) { try { Stop-Service $s -Force; Set-Service $s -StartupType Manual } catch {} }

    Get-CimInstance Win32_StartupCommand | Where-Object {$_.User -ne $null} | ForEach-Object { try { $_ | Invoke-CimMethod -MethodName Disable } catch {} }
    Log-Status "[✓] Services & Startup Apps optimization complete" Green
}

function Apply-SystemTweaks {
    Log-Status "Applying System Tweaks..." Yellow
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" -Value "0"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" "MenuShowDelay" -Value "100"
    Log-Status "[✓] System tweaks applied" Green
}

function Revert-AllChanges {
    Log-Status "Reverting all changes..." Red
    $services = @("DiagTrack","WSearch","SysMain")
    foreach ($s in $services) { try { Set-Service $s -StartupType Automatic; Start-Service $s } catch {} }
    Set-ItemProperty "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" -Value "1"
    Set-ItemProperty "HKCU:\Control Panel\Desktop" "MenuShowDelay" -Value "400"
    Log-Status "[✓] All changes reverted" Green
}

# ------------------------
# GUI SETUP
# ------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "23 Optimizer"
$form.Size = New-Object System.Drawing.Size(600,450)
$form.StartPosition = "CenterScreen"

$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter number to select category:`r`n1 = Temp & Caches`r`n2 = Disk & Pagefile`r`n3 = Memory & CPU`r`n4 = Services & Startup`r`n5 = System Tweaks`r`n6 = Revert All`r`n7 = Exit"
$label.Size = New-Object System.Drawing.Size(550,140)
$label.Location = New-Object System.Drawing.Point(20,10)
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(20,160)
$textBox.Size = New-Object System.Drawing.Size(100,25)
$form.Controls.Add($textBox)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = "Run"
$runButton.Location = New-Object System.Drawing.Point(140,160)
$runButton.Size = New-Object System.Drawing.Size(100,25)
$form.Controls.Add($runButton)

$richTextBox = New-Object System.Windows.Forms.RichTextBox
$richTextBox.Location = New-Object System.Drawing.Point(20,200)
$richTextBox.Size = New-Object System.Drawing.Size(540,200)
$richTextBox.ReadOnly = $true
$form.Controls.Add($richTextBox)

# ------------------------
# BUTTON EVENT
# ------------------------
$runButton.Add_Click({
    $choice = $textBox.Text
    switch ($choice) {
        "1" { Clear-TempAndCaches }
        "2" { Optimize-DiskAndPagefile }
        "3" { Optimize-MemoryAndCPU }
        "4" { Optimize-ServicesAndStartup }
        "5" { Apply-SystemTweaks }
        "6" { Revert-AllChanges }
        "7" { $form.Close() }
        default { Log-Status "[!] Invalid selection" Red }
    }
})

[void]$form.ShowDialog()
