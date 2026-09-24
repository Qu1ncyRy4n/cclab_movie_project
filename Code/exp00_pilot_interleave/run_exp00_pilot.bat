@echo off
REM Double-click-friendly wrapper around run_exp00_pilot.ps1 — bypasses
REM PowerShell's script-execution policy for just this one run, rather
REM than changing it system-wide.
REM
REM Usage:
REM   run_exp00_pilot.bat            the real thing
REM   run_exp00_pilot.bat -DryRun    config/path check only, no display
REM
REM pushd (not cd), since this folder may be a UNC path (e.g. reached via
REM \\wsl.localhost\...). Note this does NOT stop cmd.exe's own "UNC paths
REM are not supported, defaulting to Windows directory" warning — that
REM happens at cmd.exe's process startup, before any command in this file
REM (including pushd) gets to run. It's genuinely cosmetic: %~dp0 is still
REM computed correctly regardless, and pushd just makes any *later*
REM relative-path command in this file behave correctly too.
pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_exp00_pilot.ps1" %*
popd
pause
