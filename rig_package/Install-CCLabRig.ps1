[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\CCLabRig'
)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
$movieSource = Join-Path $packageRoot 'cclab_movie_project'
$benchSource = Join-Path $packageRoot 'mat_vs_py_bench'
if (-not (Test-Path -LiteralPath $movieSource) -or -not (Test-Path -LiteralPath $benchSource)) {
    throw 'This installer must remain beside cclab_movie_project and mat_vs_py_bench.'
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
foreach ($name in @('cclab_movie_project', 'mat_vs_py_bench')) {
    $source = Join-Path $packageRoot $name
    $target = Join-Path $InstallRoot $name
    & robocopy $source $target /E /Z /R:3 /W:5 /XD .git .venv __pycache__ data results Output_exp00_pilot Output_exp01_transitions Output_freeviewingTraining /XF .DS_Store
    if ($LASTEXITCODE -gt 7) { throw "Install of $name failed with robocopy exit code $LASTEXITCODE." }
}

Copy-Item -LiteralPath (Join-Path $packageRoot 'Start-CCLabRig.cmd') -Destination $InstallRoot -Force
Write-Host "Installed CCLab rig package to $InstallRoot" -ForegroundColor Green
Write-Host "Double-click $InstallRoot\Start-CCLabRig.cmd to run the workflow." -ForegroundColor Green
