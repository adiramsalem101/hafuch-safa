@echo off
rem Double-click to remove hafuch-safa. Everything is on one line on purpose:
rem the uninstaller deletes this file and its folder, and "(goto) 2>nul" ends
rem the batch without cmd trying to read the deleted file again.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %* & pause & (goto) 2>nul
