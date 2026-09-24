# run_exp00_pilot.ps1
#
# Launches MATLAB and runs RUN_exp00_pilot from this folder. Works no
# matter where the repo was cloned to — everything is derived from this
# script's own location ($PSScriptRoot).
#
# Usage (from PowerShell, in this folder or anywhere):
#   .\run_exp00_pilot.ps1              # the real thing — opens a PTB window
#   .\run_exp00_pilot.ps1 -DryRun      # config/path smoke test only, no
#                                       # Psychtoolbox, no display, no window
#
# -DryRun runs CONFI_exp00_pilot.m via `matlab -batch`, MATLAB's genuine
# non-interactive/headless mode (no desktop, no display needed at all).
# It only checks that computer_name resolves, video_all/ exists, and
# pilot_pool.csv parses — it never calls Screen() or anything else that
# needs a real window, so this is safe to run even if the real thing is
# currently failing to open a display for some other reason.
#
# If PowerShell blocks this as an unsigned script, either run it via the
# .bat wrapper (run_exp00_pilot.bat, double-clickable) or just once:
#   powershell -ExecutionPolicy Bypass -File .\run_exp00_pilot.ps1

param(
    [switch]$DryRun
)

$expDir = $PSScriptRoot

$matlabCmd = Get-Command matlab.exe -ErrorAction SilentlyContinue
if (-not $matlabCmd) {
    Write-Host "matlab.exe not found on PATH." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Open MATLAB manually, then in the Command Window run:"
    Write-Host "  cd('$expDir')"
    if ($DryRun) {
        Write-Host "  CONFI_exp00_pilot"
    } else {
        Write-Host "  RUN_exp00_pilot"
    }
    Write-Host ""
    Write-Host "(To make this script work directly, add MATLAB's bin folder"
    Write-Host " to your PATH, e.g. C:\Program Files\MATLAB\R2024a\bin)"
    exit 1
}

if ($DryRun) {
    Write-Host "Dry run: config/path check only, no display needed ..."
    & $matlabCmd.Source -batch "cd('$expDir'); cclab = CONFI_exp00_pilot(); disp(cclab); fprintf('CONFI OK - pool file: %s\n', cclab.poolFile); disp(readtable(cclab.poolFile));"
} else {
    Write-Host "Launching MATLAB from $expDir ..."
    & $matlabCmd.Source -sd $expDir -r "RUN_exp00_pilot"
}
