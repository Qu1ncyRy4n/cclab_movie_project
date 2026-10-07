[CmdletBinding()]
param(
    [string]$InstallRoot = 'desktop',
    [switch]$OpenFolder
)

$ErrorActionPreference = 'Stop'
$packageRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
# 'desktop' resolves the real Desktop, including one redirected into OneDrive.
if ($InstallRoot -eq 'desktop') { $InstallRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Video_Proj_exp-00' }
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
# Settings the experimenter edits are copied only once, never overwritten.
$videoFolderFile = Join-Path $InstallRoot 'video_folder.txt'
if (-not (Test-Path -LiteralPath $videoFolderFile)) {
    Copy-Item -LiteralPath (Join-Path $packageRoot 'video_folder.txt') -Destination $videoFolderFile
}
Write-Host "Installed exp_00 rig package to $InstallRoot" -ForegroundColor Green
Write-Host "In $InstallRoot, run 1_Setup_Rig.cmd, then 2_Run_Experiment.cmd. Use 3_Test_TTL.cmd, 4_Run_Benchmarks.cmd, and 5_Sync_Data.cmd as needed." -ForegroundColor Green
if ($OpenFolder) { Start-Process explorer.exe $InstallRoot }
