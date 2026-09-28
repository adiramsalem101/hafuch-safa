@echo off
rem Double-click to install hafuch-safa for the current user.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
pause
