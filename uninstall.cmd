@echo off
rem Double-click to remove hafuch-safa.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
pause
