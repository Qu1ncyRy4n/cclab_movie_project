<#
.SYNOPSIS
Create a portable CCLab rig package on a NAS share or USB drive.

.EXAMPLE
.\stage_rig_package.ps1 -BenchSource Q:\dev\mat_vs_py_bench -Destination E:\CCLabRigPackage
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BenchSource,
    [Parameter(Mandatory)]
    [string]$Destination
)

$ErrorActionPreference = 'Stop'

function Require-Path([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "$Description not found: $Path" }
}

function Copy-Tree([string]$Source, [string]$Target) {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    & robocopy $Source $Target /E /Z /R:3 /W:5 /XD .git .venv __pycache__ data results Output_exp00_pilot Output_exp01_transitions Output_freeviewingTraining /XF .DS_Store
    if ($LASTEXITCODE -gt 7) { throw "Copy from $Source failed with robocopy exit code $LASTEXITCODE." }
}

Require-Path $PSScriptRoot 'Movie-project repository'
Require-Path $BenchSource 'Benchmark repository'
Require-Path (Join-Path $PSScriptRoot 'rig_package\Install-CCLabRig.ps1') 'Package installer'
Require-Path (Join-Path $PSScriptRoot 'Code\cclab-matlab-tools\cclabInitDIO.m') 'Initialized cclab MATLAB tools submodule'
if (Test-Path -LiteralPath $Destination) {
    throw "Destination already exists: $Destination. Use a new empty folder so the package cannot contain stale code."
}

New-Item -ItemType Directory -Path $Destination | Out-Null
Copy-Tree $PSScriptRoot (Join-Path $Destination 'cclab_movie_project')
Copy-Tree $BenchSource (Join-Path $Destination 'mat_vs_py_bench')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rig_package\Install-CCLabRig.ps1') -Destination $Destination
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rig_package\Start-CCLabRig.cmd') -Destination $Destination

@"
CCLab Rig Package
=================

On the experiment machine, copy this whole folder from the NAS or USB drive to a
local drive. Then double-click Install-CCLabRig.ps1 or run it from PowerShell.
The experiment must run from the local drive, never directly from the NAS/USB.
"@ | Set-Content -LiteralPath (Join-Path $Destination 'README.txt')

Write-Host "Portable package created: $Destination" -ForegroundColor Green
