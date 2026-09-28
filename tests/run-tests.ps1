<#
.SYNOPSIS
    Runs the hafuch-safa tests.

.DESCRIPTION
    unit    pure conversion logic (tests\unit-tests.ahk)
    layout  compares the built-in key map with the layouts installed in Windows
    e2e     drives the RUNNING tool with real keystrokes in a test window
            (only with -E2E; do not touch the keyboard or mouse while it runs)

    Every test process gets a hard timeout of 60 seconds.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tests\run-tests.ps1 -E2E
#>
param(
    [switch]$E2E,
    [string]$Config = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

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
                $version = (Get-Item $candidate).VersionInfo.ProductVersion
                if ($version -and $version.StartsWith('2.')) { return $candidate }
            }
        }
    }
    return $null
}

function Invoke-AhkScript([string]$Script, [string[]]$Arguments, [int]$TimeoutSec = 60) {
    $out = [IO.Path]::GetTempFileName()
    $err = [IO.Path]::GetTempFileName()
    try {
        $argList = @('/ErrorStdOut', ('"{0}"' -f $Script)) + @($Arguments | ForEach-Object { '"{0}"' -f $_ })
        $p = Start-Process -FilePath $script:ahk -ArgumentList $argList -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
        $null = $p.Handle
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill() } catch { }
            Write-Host "TIMEOUT: $Script did not finish within $TimeoutSec s"
            return 124
        }
        Get-Content $out -Encoding UTF8 | ForEach-Object { Write-Host $_ }
        Get-Content $err -Encoding UTF8 | ForEach-Object { Write-Host $_ }
        return $p.ExitCode
    }
    finally {
        Remove-Item $out, $err -ErrorAction SilentlyContinue
    }
}

$script:ahk = Find-AutoHotkey
if (-not $script:ahk) {
    Write-Host 'AutoHotkey v2 was not found. Run install.ps1 first.'
    exit 2
}

$results = [ordered]@{}

Write-Host '== unit tests =='
$results['unit'] = Invoke-AhkScript (Join-Path $here 'unit-tests.ahk') @()

Write-Host ''
Write-Host '== key map vs installed layouts =='
$results['layout'] = Invoke-AhkScript (Join-Path $here 'layout-check.ahk') @()

if ($E2E) {
    if (-not $Config) {
        $installed = Join-Path $env:LOCALAPPDATA 'hafuch-safa\config.ini'
        $Config = if (Test-Path $installed) { $installed } else { Join-Path (Split-Path $here) 'config.ini' }
    }
    Write-Host ''
    Write-Host "== end-to-end (config: $Config) =="
    # Exit code 99 means the run stopped because another window took focus
    # (or the computer was in use); nothing was typed elsewhere. Try again.
    foreach ($attempt in 1..3) {
        $code = Invoke-AhkScript (Join-Path $here 'e2e-test.ahk') @($Config)
        if ($code -ne 99) { break }
        Write-Host "(interrupted, attempt $attempt of 3)"
        Start-Sleep -Seconds 2
    }
    $results['e2e'] = $code
}

Write-Host ''
$failed = 0
foreach ($name in $results.Keys) {
    $code = $results[$name]
    $status = if ($code -eq 0) { 'PASS' } else { "FAIL (exit $code)" }
    Write-Host ('{0,-8} {1}' -f $name, $status)
    if ($code -ne 0) { $failed++ }
}
exit $failed
