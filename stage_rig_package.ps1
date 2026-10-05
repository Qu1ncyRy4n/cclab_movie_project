<#
.SYNOPSIS
Create a portable CCLab rig package on a NAS share or USB drive.

.DESCRIPTION
With no arguments, stages from the sibling mat_vs_py_bench checkout to a new
date-stamped folder under the NAS experiment_packages share. On the lab
computer, run ./stage_to_nas.sh from WSL instead; it checks and pulls both
repositories first.

.EXAMPLE
.\stage_rig_package.ps1 -BenchSource Q:\dev\mat_vs_py_bench -Destination E:\CCLabRigPackage
#>
[CmdletBinding()]
param(
    [string]$BenchSource,
    [string]$Destination,
    [string]$PackagesRoot = '\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages'
)

$ErrorActionPreference = 'Stop'
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $BenchSource) { $BenchSource = Join-Path $scriptRoot '..\..\research_infra\mat_vs_py_bench' }
if (-not $Destination) {
    # Never reuse a package folder: exp00_<date>, then exp00_<date>_2, _3, ...
    $base = Join-Path $PackagesRoot ('exp00_' + (Get-Date -Format 'yyyy-MM-dd'))
    $Destination = $base
    for ($n = 2; Test-Path -LiteralPath $Destination; $n++) { $Destination = "${base}_$n" }
}

function Require-Path([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "$Description not found: $Path" }
}

function Copy-Tree([string]$Source, [string]$Target) {
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    & robocopy $Source $Target /E /Z /R:3 /W:5 /XD .git .venv .direnv __pycache__ data results Output_exp00_pilot Output_exp01_transitions Output_freeviewingTraining /XF .DS_Store
    if ($LASTEXITCODE -gt 7) { throw "Copy from $Source failed with robocopy exit code $LASTEXITCODE." }
}

Require-Path $scriptRoot 'Movie-project repository'
Require-Path $BenchSource 'Benchmark repository'
Require-Path (Join-Path $scriptRoot 'rig_package\Install-CCLabRig.ps1') 'Package installer'
Require-Path (Join-Path $scriptRoot 'Code\cclab-matlab-tools\cclabInitDIO.m') 'Initialized cclab MATLAB tools submodule'
if (Test-Path -LiteralPath $Destination) {
    throw "Destination already exists: $Destination. Use a new empty folder so the package cannot contain stale code."
}

New-Item -ItemType Directory -Path $Destination | Out-Null
Copy-Tree $scriptRoot (Join-Path $Destination 'cclab_movie_project')
Copy-Tree $BenchSource (Join-Path $Destination 'mat_vs_py_bench')
Copy-Item -LiteralPath (Join-Path $scriptRoot 'rig_package\Install-CCLabRig.ps1') -Destination $Destination
Get-ChildItem -LiteralPath (Join-Path $scriptRoot 'rig_package') -Filter '*.cmd' | Copy-Item -Destination $Destination

@"
CCLab Rig Package
=================

On the experiment machine, double-click Install-CCLabRig.cmd in this folder. It
copies the code to a local folder (C:\CCLabRig by default) and opens it. There,
double-click in order:
  1_Setup_Rig.cmd  2_Run_Benchmarks.cmd  3_Run_Experiment.cmd
The experiment must run from the local drive, never directly from the NAS/USB.
"@ | Set-Content -LiteralPath (Join-Path $Destination 'README.txt')

Write-Host "Portable package created: $Destination" -ForegroundColor Green
