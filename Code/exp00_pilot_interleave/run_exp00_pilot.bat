@echo off
REM Double-click-friendly wrapper around run_exp00_pilot.ps1 — bypasses
REM PowerShell's script-execution policy for just this one run, rather
REM than changing it system-wide.
REM
REM pushd (not cd) because this folder may be a UNC path (e.g. reached via
REM \\wsl.localhost\...) — plain cmd.exe refuses a UNC current directory
REM and prints a "defaulting to Windows directory" warning; pushd maps a
REM temp drive letter instead, which cmd.exe does support. Harmless either
REM way (%~dp0 below doesn't depend on cmd's cwd), but this avoids the
REM scary-looking warning.
pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_exp00_pilot.ps1"
popd
pause
