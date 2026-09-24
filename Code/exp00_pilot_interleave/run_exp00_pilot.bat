@echo off
REM Double-click-friendly wrapper around run_exp00_pilot.ps1 — bypasses
REM PowerShell's script-execution policy for just this one run, rather
REM than changing it system-wide.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_exp00_pilot.ps1"
pause
