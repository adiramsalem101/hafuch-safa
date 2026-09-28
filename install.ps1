<#
.SYNOPSIS
    Installs hafuch-safa for the current user. No administrator rights needed.

.DESCRIPTION
    1. Installs AutoHotkey v2 with winget (per-user scope) if it is missing.
    2. Copies the tool to %LOCALAPPDATA%\hafuch-safa. An existing config.ini
       there is kept, so reinstalling or upgrading keeps your settings.
    3. Adds a shortcut to your Startup folder so the tool runs at sign-in.
    4. Starts the tool.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1 -NoAutostart
#>
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'hafuch-safa'),
    [switch]$NoAutostart,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$Version = '1.0.0'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $InstallDir 'hafuch-safa.ahk'
$statePath = Join-Path $InstallDir 'install-state.json'
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'hafuch-safa.lnk'

function Write-Step([string]$Text) { Write-Host "==> $Text" }

function Find-AutoHotkey {
    $exe = if ([Environment]::Is64BitOperatingSystem) { 'AutoHotkey64.exe' } else { 'AutoHotkey32.exe' }
    $dirs = @()
    foreach ($key in 'HKCU:\SOFTWARE\AutoHotkey', 'HKLM:\SOFTWARE\AutoHotkey', 'HKLM:\SOFTWARE\WOW6432Node\AutoHotkey') {
        $dir = (Get-ItemProperty -Path $key -Name InstallDir -ErrorAction SilentlyContinue).InstallDir
        if ($dir) { $dirs += $dir }
    }
    $dirs += "$env:LOCALAPPDATA\Programs\AutoHotkey", "$env:ProgramFiles\AutoHotkey"
    foreach ($dir in $dirs) {
        foreach ($candidate in (Join-Path $dir "v2\$exe"), (Join-Path $dir $exe)) {
            if (Test-Path $candidate) {
                $v = (Get-Item $candidate).VersionInfo.ProductVersion
                if ($v -and $v.StartsWith('2.')) { return $candidate }
            }
        }
    }
    return $null
}

# Processes running any copy of hafuch-safa.ahk (only this tool, nothing else).
function Get-ToolProcesses {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -like '*hafuch-safa.ahk*' }
}

foreach ($file in 'hafuch-safa.ahk', 'config.ini', 'lib\core.ahk', 'lib\layouts.ahk', 'lib\system.ahk') {
    if (-not (Test-Path (Join-Path $source $file))) {
        throw "Missing $file next to install.ps1. Run the script from the project folder."
    }
}

$previous = $null
if (Test-Path $statePath) {
    try { $previous = Get-Content $statePath -Raw | ConvertFrom-Json } catch { $previous = $null }
}

# 1. AutoHotkey v2
$ahk = Find-AutoHotkey
$installedAhk = [bool]($previous -and $previous.autoHotkeyInstalledByInstaller)
if ($ahk) {
    Write-Step "AutoHotkey v2 found: $ahk"
}
else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'AutoHotkey v2 is missing and winget is not available. Install AutoHotkey v2 from https://www.autohotkey.com and run install.ps1 again.'
    }
    Write-Step 'Installing AutoHotkey v2 for the current user (winget)...'
    & winget install --id AutoHotkey.AutoHotkey --exact --source winget --scope user --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    $ahk = Find-AutoHotkey
    if (-not $ahk) { throw 'AutoHotkey v2 could not be installed. Install it from https://www.autohotkey.com and run install.ps1 again.' }
    $installedAhk = $true
    Write-Step "AutoHotkey v2 installed: $ahk"
}

# 2. Stop a running copy, then copy the files
foreach ($p in @(Get-ToolProcesses)) {
    Write-Step "Stopping the running copy (process $($p.ProcessId))"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

$sameFolder = [IO.Path]::GetFullPath($source).TrimEnd('\') -ieq [IO.Path]::GetFullPath($InstallDir).TrimEnd('\')
if (-not $sameFolder) {
    Write-Step "Copying files to $InstallDir"
    New-Item -ItemType Directory -Force -Path $InstallDir, (Join-Path $InstallDir 'lib'), (Join-Path $InstallDir 'assets') | Out-Null
    Copy-Item (Join-Path $source 'hafuch-safa.ahk') $InstallDir -Force
    Copy-Item (Join-Path $source 'lib\*.ahk') (Join-Path $InstallDir 'lib') -Force
    foreach ($file in 'README.md', 'ASSUMPTIONS.md', 'LICENSE', 'uninstall.ps1', 'uninstall.cmd') {
        $f = Join-Path $source $file
        if (Test-Path $f) { Copy-Item $f $InstallDir -Force }
    }
    $icon = Join-Path $source 'assets\hafuch-safa.ico'
    if (Test-Path $icon) { Copy-Item $icon (Join-Path $InstallDir 'assets') -Force }
    $config = Join-Path $InstallDir 'config.ini'
    if (Test-Path $config) {
        Write-Step 'Keeping your existing config.ini'
    }
    else {
        Copy-Item (Join-Path $source 'config.ini') $config
    }
}

# 3. Start at sign-in
if ($NoAutostart) {
    if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
}
else {
    Write-Step "Adding a Startup shortcut: $shortcutPath"
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($shortcutPath)
    $lnk.TargetPath = $ahk
    $lnk.Arguments = '"' + $scriptPath + '"'
    $lnk.WorkingDirectory = $InstallDir
    $iconPath = Join-Path $InstallDir 'assets\hafuch-safa.ico'
    if (Test-Path $iconPath) { $lnk.IconLocation = "$iconPath,0" }
    $lnk.Description = 'hafuch-safa: flips text typed in the wrong keyboard layout (Hebrew/English)'
    $lnk.Save()
}

$state = [ordered]@{
    version                        = $Version
    installedAt                    = (Get-Date).ToString('s')
    installDir                     = $InstallDir
    autoHotkey                     = $ahk
    autoHotkeyInstalledByInstaller = $installedAhk
    startupShortcut                = $(if ($NoAutostart) { '' } else { $shortcutPath })
}
$state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8

# 4. Start it
if (-not $NoLaunch) {
    Write-Step 'Starting hafuch-safa'
    Start-Process -FilePath $ahk -ArgumentList ('"' + $scriptPath + '"') -WorkingDirectory $InstallDir
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 300
        $running = @(Get-ToolProcesses | Where-Object { $_.CommandLine -like "*$InstallDir*" })
    } while (-not $running.Count -and (Get-Date) -lt $deadline)
    if (-not $running.Count) { throw 'hafuch-safa did not start. Try running hafuch-safa.ahk from the install folder.' }
}

$hotkey = 'Ctrl+Alt+L'
$line = Select-String -Path (Join-Path $InstallDir 'config.ini') -Pattern '^\s*Hotkey\s*=\s*(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($line) { $hotkey = $line.Matches[0].Groups[1].Value.Trim() }

Write-Host ''
Write-Host "hafuch-safa $Version is installed and running."
Write-Host "  Hotkey:    $hotkey"
Write-Host "  Settings:  $(Join-Path $InstallDir 'config.ini')"
Write-Host "  Uninstall: powershell -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $InstallDir 'uninstall.ps1')`""
