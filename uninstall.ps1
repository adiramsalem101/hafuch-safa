<#
.SYNOPSIS
    Removes hafuch-safa: stops it, deletes the Startup shortcut and the
    install folder, and uninstalls AutoHotkey if install.ps1 installed it.

.PARAMETER KeepConfig
    Keep config.ini in the install folder (everything else is removed).

.PARAMETER KeepAutoHotkey
    Leave AutoHotkey installed even if install.ps1 installed it.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
#>
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'hafuch-safa'),
    [switch]$KeepConfig,
    [switch]$KeepAutoHotkey
)

$ErrorActionPreference = 'Stop'
function Write-Step([string]$Text) { Write-Host "==> $Text" }

$statePath = Join-Path $InstallDir 'install-state.json'
$state = $null
if (Test-Path $statePath) {
    try { $state = Get-Content $statePath -Raw | ConvertFrom-Json } catch { $state = $null }
}

# 1. Stop the tool (only processes running hafuch-safa.ahk)
$procs = @(Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -like '*hafuch-safa.ahk*' })
foreach ($p in $procs) {
    Write-Step "Stopping hafuch-safa (process $($p.ProcessId))"
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}

# 2. Startup shortcut
$shortcuts = @(Join-Path ([Environment]::GetFolderPath('Startup')) 'hafuch-safa.lnk')
if ($state -and $state.startupShortcut) { $shortcuts += $state.startupShortcut }
foreach ($s in ($shortcuts | Select-Object -Unique)) {
    if (Test-Path $s) {
        Write-Step "Removing $s"
        Remove-Item $s -Force
    }
}

# 3. Install folder
if (Test-Path $InstallDir) {
    Set-Location $env:TEMP   # the folder cannot be removed while it is the current folder
    if ($KeepConfig) {
        Write-Step "Removing $InstallDir (keeping config.ini)"
        Get-ChildItem -Path $InstallDir -Force | Where-Object { $_.Name -ne 'config.ini' } | Remove-Item -Recurse -Force
    }
    else {
        Write-Step "Removing $InstallDir"
        Remove-Item $InstallDir -Recurse -Force
    }
}

# 4. AutoHotkey, only if install.ps1 installed it
if ($state -and $state.autoHotkeyInstalledByInstaller -and -not $KeepAutoHotkey) {
    $others = @(Get-Process -Name 'AutoHotkey*' -ErrorAction SilentlyContinue)
    if ($others.Count) {
        Write-Warning 'Other AutoHotkey scripts are running, so AutoHotkey was left installed.'
    }
    elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Step 'Uninstalling AutoHotkey (it was installed by install.ps1)'
        & winget uninstall --id AutoHotkey.AutoHotkey --exact --source winget --scope user --silent --disable-interactivity
    }
}
elseif ($state -and $state.autoHotkeyInstalledByInstaller) {
    Write-Step 'AutoHotkey left installed (-KeepAutoHotkey)'
}

Write-Host ''
Write-Host 'hafuch-safa was removed.'
