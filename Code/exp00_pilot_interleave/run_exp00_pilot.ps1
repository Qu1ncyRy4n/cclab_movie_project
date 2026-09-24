# run_exp00_pilot.ps1
#
# Launches MATLAB and runs RUN_exp00_pilot from this folder. Works no
# matter where the repo was cloned to — everything is derived from this
# script's own location ($PSScriptRoot).
#
# Usage (from PowerShell, in this folder or anywhere):
#   .\run_exp00_pilot.ps1
#
# If PowerShell blocks it as an unsigned script, either run it via the
# .bat wrapper (run_exp00_pilot.bat, double-clickable) or just once:
#   powershell -ExecutionPolicy Bypass -File .\run_exp00_pilot.ps1

$expDir = $PSScriptRoot

$matlabCmd = Get-Command matlab.exe -ErrorAction SilentlyContinue
if (-not $matlabCmd) {
    Write-Host "matlab.exe not found on PATH." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Open MATLAB manually, then in the Command Window run:"
    Write-Host "  cd('$expDir')"
    Write-Host "  RUN_exp00_pilot"
    Write-Host ""
    Write-Host "(To make this script work directly, add MATLAB's bin folder"
    Write-Host " to your PATH, e.g. C:\Program Files\MATLAB\R2024a\bin)"
    exit 1
}

Write-Host "Launching MATLAB from $expDir ..."
& $matlabCmd.Source -sd $expDir -r "RUN_exp00_pilot"
