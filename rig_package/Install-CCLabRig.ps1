[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\CCLabRig',
    [switch]$OpenFolder
)

$ErrorActionPreference = 'Stop'
$packageRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
# 'desktop' resolves the real Desktop, including one redirected into OneDrive.
if ($InstallRoot -eq 'desktop') { $InstallRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'CCLabRig' }
$movieSource = Join-Path $packageRoot 'cclab_movie_project'
$benchSource = Join-Path $packageRoot 'mat_vs_py_bench'
if (-not (Test-Path -LiteralPath $movieSource) -or -not (Test-Path -LiteralPath $benchSource)) {
    throw 'This installer must remain beside cclab_movie_project and mat_vs_py_bench.'
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
foreach ($name in @('cclab_movie_project', 'mat_vs_py_bench')) {
    $source = Join-Path $packageRoot $name
    $target = Join-Path $InstallRoot $name
    # /MIR makes a reinstall match the package exactly (no stale code). Excluded
    # folders such as .venv are neither copied nor purged; run data lives in
    # $InstallRoot\data, outside both mirrored folders.
    & robocopy $source $target /MIR /Z /R:3 /W:5 /XD .git .venv .direnv __pycache__ data results Output_exp00_pilot Output_exp01_transitions Output_freeviewingTraining /XF .DS_Store
    if ($LASTEXITCODE -gt 7) { throw "Install of $name failed with robocopy exit code $LASTEXITCODE." }
}

Get-ChildItem -LiteralPath $packageRoot -Filter '?_*.cmd' | Copy-Item -Destination $InstallRoot -Force
Write-Host "Installed CCLab rig package to $InstallRoot" -ForegroundColor Green
Write-Host "In $InstallRoot, double-click 1_Setup_Rig.cmd, then 2_Run_Benchmarks.cmd, then 3_Run_Experiment.cmd." -ForegroundColor Green
if ($OpenFolder) { Start-Process explorer.exe $InstallRoot }
