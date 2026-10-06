@echo off
rem Double-click to remove hafuch-safa. Everything is on one line on purpose:
rem the uninstaller deletes this file, so cmd must not read any further line.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %* & pause & exit /b
