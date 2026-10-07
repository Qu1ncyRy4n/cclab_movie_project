<#
.SYNOPSIS
Play each planned QC window in VLC and record a resumable manual review.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File .\REVIEW_exp00_windows.ps1 `
  -QcCsv "C:\...\qc_source_windows.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$QcCsv,
    [string]$VideoRoot = "$env:USERPROFILE\Desktop\video_ebm_dataset\video_all"
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $QcCsv)) { throw "QC CSV not found: $QcCsv" }
if (-not (Test-Path -LiteralPath $VideoRoot)) { throw "Video folder not found: $VideoRoot" }

$vlcCandidates = @(
    "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
    "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe",
    (Get-Command vlc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if (-not $vlcCandidates) {
    throw 'VLC was not found. Install VLC or add vlc.exe to PATH, then run this script again.'
}
$vlc = $vlcCandidates[0]

$reviewFile = Join-Path (Split-Path -Parent $QcCsv) 'qc_review.csv'
$windows = Import-Csv -LiteralPath $QcCsv
if (-not $windows -or -not (@($windows[0].PSObject.Properties.Name) -contains 'Video')) {
    throw 'QC CSV must contain Video, Category, Start_s, and End_s columns.'
}
$prior = @{}
if (Test-Path -LiteralPath $reviewFile) {
    Import-Csv -LiteralPath $reviewFile | ForEach-Object { $prior["$($_.Video)|$($_.Start_s)"] = $_ }
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($window in $windows) {
    $key = "$($window.Video)|$($window.Start_s)"
    if ($prior.ContainsKey($key) -and $prior[$key].Status -in @('PASS', 'REJECT')) {
        $results.Add($prior[$key])
        continue
    }

    $video = Join-Path $VideoRoot $window.Video
    if (-not (Test-Path -LiteralPath $video)) { throw "Video not found: $video" }
    $duration = [double]$window.End_s - [double]$window.Start_s
    Write-Host "`n$($window.Category): $($window.Video), $($window.Start_s) to $($window.End_s) s" -ForegroundColor Cyan
    Start-Process -FilePath $vlc -ArgumentList @(
        "--start-time=$($window.Start_s)", "--run-time=$duration", '--play-and-exit', '--no-video-title-show', $video
    ) -Wait

    do { $status = (Read-Host 'Result: [p]ass, [r]eject, [s]kip, or [q]uit').Trim().ToLower() }
    while ($status -notin @('p', 'r', 's', 'q'))
    if ($status -eq 'q') { break }
    $note = if ($status -eq 'r') { Read-Host 'Brief rejection reason' } else { '' }
    $results.Add([pscustomobject]@{
        Video = $window.Video; Category = $window.Category; Start_s = $window.Start_s; End_s = $window.End_s
        Status = @{ p = 'PASS'; r = 'REJECT'; s = 'SKIP' }[$status]; Notes = $note
    })
    $results | Export-Csv -LiteralPath $reviewFile -NoTypeInformation
}

$results | Export-Csv -LiteralPath $reviewFile -NoTypeInformation
Write-Host "Review saved: $reviewFile" -ForegroundColor Green
