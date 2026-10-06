<#
    One-line installer for hafuch-safa. Paste into cmd, PowerShell,
    Windows Terminal or the Run box (Win+R):

    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/adiramsalem101/hafuch-safa/main/get.ps1 | iex"

    Downloads the project from GitHub into a temporary folder, runs
    install.ps1 from there (current user only, no administrator rights)
    and deletes the temporary folder.
#>
& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # the progress bar makes downloads very slow in PowerShell 5.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repo = 'adiramsalem101/hafuch-safa'
    $work = Join-Path $env:TEMP ('hafuch-safa-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $zip = "$work.zip"
    try {
        Write-Host "==> Downloading hafuch-safa from github.com/$repo"
        Invoke-WebRequest -Uri "https://github.com/$repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $work -Force
        $source = Get-ChildItem -Path $work -Directory | Select-Object -First 1
        if (-not $source -or -not (Test-Path (Join-Path $source.FullName 'install.ps1'))) {
            throw 'The download does not contain install.ps1.'
        }
        Get-ChildItem -Path $source.FullName -Recurse -File | Unblock-File
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $source.FullName 'install.ps1')
        if ($LASTEXITCODE) { throw "install.ps1 stopped with exit code $LASTEXITCODE." }
    }
    catch {
        Write-Host "hafuch-safa was not installed: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        Remove-Item -Path $zip, $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
