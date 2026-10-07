<#
.SYNOPSIS
Copy one or more completed local rig runs to a NAS/archive after an outage.

.DESCRIPTION
Copies only. It never deletes or moves the local source run. Robocopy exit
codes 0-7 are successful copy outcomes; codes above 7 are failures.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ArchiveRoot,
    [string]$RunRoot,
    [string]$SessionId,
    [switch]$All
)

$ErrorActionPreference = 'Stop'
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $RunRoot) { $RunRoot = Join-Path (Split-Path $scriptRoot -Parent) 'data\runs' }

if ([string]::IsNullOrWhiteSpace($SessionId) -eq $All.IsPresent) {
    throw 'Provide exactly one of -SessionId or -All.'
}
if (-not (Test-Path -LiteralPath $RunRoot -PathType Container)) {
    throw "Local run root not found: $RunRoot"
}

if ($All) {
    $runs = Get-ChildItem -LiteralPath $RunRoot -Directory | Sort-Object Name
}
else {
    $run = Join-Path $RunRoot $SessionId
    if (-not (Test-Path -LiteralPath $run -PathType Container)) {
        throw "Local session folder not found: $run"
    }
    $runs = Get-Item -LiteralPath $run
}

New-Item -ItemType Directory -Force -Path $ArchiveRoot | Out-Null
foreach ($run in $runs) {
    $destination = Join-Path $ArchiveRoot $run.Name
    Write-Host "Syncing $($run.FullName) -> $destination" -ForegroundColor Cyan
    & robocopy $run.FullName $destination /E /Z /R:3 /W:5 /COPY:DAT /DCOPY:DAT /NFL /NDL
    if ($LASTEXITCODE -gt 7) {
        throw "Archive copy failed for $($run.Name) with robocopy exit code $LASTEXITCODE. Local data remains unchanged."
    }
    Write-Host "Synced: $destination" -ForegroundColor Green
}

Write-Host 'Sync complete. Local source data was not deleted.' -ForegroundColor Green
