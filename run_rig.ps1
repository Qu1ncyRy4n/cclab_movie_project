<#
.SYNOPSIS
Set up, benchmark, or run the exp_00 MATLAB pilot on a CCLab Windows rig.

.DESCRIPTION
Modes (the rig_package launchers call one each):
  -Setup          copy pilot videos locally, install the Python env, preflight, video check
  (no mode flag)  MATLAB/Python timing benchmarks only
  -RunExperiment  benchmarks, then the exp_00 pilot (add -SkipBench for the pilot only)
  -DryRun         headless exp_00 configuration and video check only
Every run gets its own timestamped local folder. Optionally, the completed
folder is copied to a NAS or USB destination without deleting the local source.
#>
[CmdletBinding()]
param(
    [string]$BenchRoot,
    [string]$RigConfig,
    [string]$RunRoot,
    [string]$ArchiveRoot,
    [ValidateSet('local', 'nas')]
    [string]$VideoSource = 'local',
    [string]$VideoRoot,
    [string]$NasVideoRoot = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset',
    [string]$LocalVideoRoot = 'C:\cclab_data\video_ebm_dataset',
    [string]$SessionId = (Get-Date -Format 'yyyy-MM-dd_HHmmss'),
    [ValidateSet('Vennie', 'Isaac', 'DEV-00')]
    [string]$SubjectId,
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$')]
    [string]$Experimenter,
    [int]$Screen = -1,
    [int]$Frames = 3000,
    [int]$Pulses = 10000,
    [int]$Flips = 300,
    [ValidateSet('lab_120', 'lab_121', 'win_dummy', 'dev_wsl')]
    [string]$ComputerProfile = 'lab_120',
    [ValidateSet('auto', 'on', 'off')]
    [string]$EyeTracking = 'auto',
    [ValidateSet('auto', 'on', 'off')]
    [string]$NeuralIO = 'auto',
    [ValidateRange(1, 2000)]
    [int]$RewardMs = 400,
    [switch]$Setup,
    [switch]$RunExperiment,
    [switch]$SkipBench,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$script:Completed = $false

# Windows PowerShell 5.1 leaves $PSScriptRoot empty while evaluating param()
# defaults under `powershell.exe -File`, so path defaults are resolved here.
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $BenchRoot) { $BenchRoot = Join-Path $scriptRoot '..\mat_vs_py_bench' }
# win_dummy/dev_wsl have no NI card, photodiode, or stimulus display, so the
# benchmarks run on synthetic DIO and the MATLAB T2 (no dummy mode) is skipped.
$benchDummy = $ComputerProfile -in @('win_dummy', 'dev_wsl')
$defaultRig = if ($benchDummy) { 'dummy.txt' } else { 'rig-right.txt' }
if (-not $RigConfig) { $RigConfig = Join-Path $scriptRoot "Code\cclab-matlab-tools\cfg\$defaultRig" }
if ($Screen -lt 0) { $Screen = if ($benchDummy) { 0 } else { 2 } }
if (-not $RunRoot) { $RunRoot = Join-Path (Split-Path $scriptRoot -Parent) 'data\runs' }

# video_folder.txt beside the launchers overrides the local video location
# without editing code: first non-comment line, either the dataset folder or
# its video_all subfolder.
$videoFolderFile = Join-Path (Split-Path $scriptRoot -Parent) 'video_folder.txt'
if (-not $PSBoundParameters.ContainsKey('LocalVideoRoot') -and (Test-Path -LiteralPath $videoFolderFile)) {
    $line = Get-Content -LiteralPath $videoFolderFile |
        ForEach-Object { $_.Trim().Trim('"') } |
        Where-Object { $_ -and -not $_.StartsWith('#') } |
        Select-Object -First 1
    if ($line) {
        $line = [Environment]::ExpandEnvironmentVariables($line).TrimEnd('\')
        if ((Split-Path $line -Leaf) -eq 'video_all') { $line = Split-Path $line -Parent }
        $LocalVideoRoot = $line
        Write-Host "Local videos (from video_folder.txt): $LocalVideoRoot"
    }
}

if (@($Setup, $DryRun, $RunExperiment | Where-Object { $_ }).Count -gt 1) {
    throw 'Use only one of -Setup, -DryRun, or -RunExperiment.'
}
$runBench = -not ($Setup -or $DryRun -or $SkipBench)
if (-not $PSBoundParameters.ContainsKey('SessionId')) {
    $mode = if ($Setup) { 'setup' } elseif ($DryRun) { 'dryrun' }
            elseif ($RunExperiment -and $runBench) { 'bench_exp' } elseif ($RunExperiment) { 'exp' } else { 'bench' }
    $SessionId = "${SessionId}_$mode"
}

function Require-Path([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Description not found: $Path"
    }
}

function Invoke-Checked([string]$Description, [scriptblock]$Command) {
    Write-Host "`n== $Description ==" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

function Copy-RunToArchive([string]$Source, [string]$Destination) {
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    & robocopy $Source $Destination /E /Z /R:3 /W:5 /COPY:DAT /DCOPY:DAT /NFL /NDL
    if ($LASTEXITCODE -gt 7) {
        throw "Archive copy failed with robocopy exit code $LASTEXITCODE. Local run remains at $Source."
    }
    # Robocopy uses 1-7 for successful copies with informational differences.
    # Prevent Invoke-Checked from treating a successful copy as a failure.
    $global:LASTEXITCODE = 0
}

function Copy-PilotVideos([string]$PoolCsv, [string]$Source, [string]$Destination) {
    $sourceDir = Join-Path $Source 'video_all'
    $destinationDir = Join-Path $Destination 'video_all'
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    $pool = Import-Csv -LiteralPath $PoolCsv
    foreach ($video in $pool.filename) {
        $target = Join-Path $destinationDir $video
        if (Test-Path -LiteralPath $target) { Write-Host "  present  $video"; continue }
        $sourceFile = Join-Path $sourceDir $video
        Require-Path $sourceFile 'Pilot video on the NAS'
        Copy-Item -LiteralPath $sourceFile -Destination $target
        Write-Host "  copied   $video"
    }
    Write-Host "$(@($pool).Count) pilot videos in $destinationDir"
}

function Get-OrInstall-UV {
    $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
    if ($uvCommand) { return $uvCommand }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) { $winget = Get-Command winget -ErrorAction SilentlyContinue }
    if (-not $winget) {
        throw 'uv is not on PATH and winget is unavailable. Install UV manually: https://docs.astral.sh/uv/'
    }

    Write-Host 'UV is missing; installing it with winget...' -ForegroundColor Yellow
    & $winget.Source install --id astral-sh.uv -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install UV (exit code $LASTEXITCODE)." }

    $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uvCommand) {
        $installedUv = Join-Path $env:USERPROFILE '.local\bin\uv.exe'
        if (Test-Path -LiteralPath $installedUv) {
            $uvCommand = Get-Command $installedUv
        }
    }
    if (-not $uvCommand) {
        throw 'UV was installed but is not available to this PowerShell session. Close this window, open a new one, and run again.'
    }
    return $uvCommand
}

Require-Path $scriptRoot 'Movie-project repository'
Require-Path $BenchRoot 'Benchmark repository'
Require-Path (Join-Path $scriptRoot 'Code\exp00_pilot_interleave\RUN_exp00_pilot.m') 'exp_00 MATLAB entry point'
Require-Path (Join-Path $scriptRoot 'Code\cclab-matlab-tools\cclabInitDIO.m') 'cclab MATLAB tools'

if ($RunExperiment -and -not $SubjectId) {
    throw '-SubjectId (Vennie, Isaac, or DEV-00) is required with -RunExperiment.'
}
if ($RunExperiment -and -not $Experimenter) {
    throw '-Experimenter is required with -RunExperiment.'
}
if (-not $DryRun) {
    Require-Path $RigConfig 'Rig configuration'
    Require-Path (Join-Path $BenchRoot 'matlab\t2_photodiode.m') 'MATLAB benchmark arm'
}

if (-not $DryRun -and ($Setup -or $runBench)) { $uv = Get-OrInstall-UV }

$matlab = Get-Command matlab.exe -ErrorAction SilentlyContinue
if (-not $matlab) { $matlab = Get-Command matlab -ErrorAction SilentlyContinue }
if (-not $matlab) {
    throw 'MATLAB is not on PATH. Add MATLAB\bin to PATH, then run this script again.'
}

$movieRoot = (Resolve-Path -LiteralPath $scriptRoot)
$benchRoot = (Resolve-Path -LiteralPath $BenchRoot)
$runDir = Join-Path $RunRoot $SessionId
if (Test-Path -LiteralPath $runDir) {
    throw "Run folder already exists: $runDir. Choose a new -SessionId."
}

$logsDir = Join-Path $runDir 'logs'
$experimentDir = Join-Path $runDir 'experiment'
$benchDir = Join-Path $runDir 'benchmark'
New-Item -ItemType Directory -Force -Path $logsDir, $experimentDir, $benchDir | Out-Null

$rigConfigResolved = $null
if (-not $DryRun) {
    $rigConfigResolved = (Resolve-Path -LiteralPath $RigConfig)
    $env:CCLAB_RIG_CONFIG = $rigConfigResolved.Path
}
$env:CCLAB_COMPUTER_NAME = $ComputerProfile
$env:CCLAB_VIDEO_SOURCE = $VideoSource
$env:CCLAB_EXPERIMENTER = $Experimenter
$env:CCLAB_REWARD_MS = $RewardMs
if ($EyeTracking -eq 'auto') { Remove-Item Env:CCLAB_USE_EYELINK -ErrorAction SilentlyContinue }
else { $env:CCLAB_USE_EYELINK = $EyeTracking }
if ($NeuralIO -eq 'auto') { Remove-Item Env:CCLAB_USE_NEURAL_IO -ErrorAction SilentlyContinue }
else { $env:CCLAB_USE_NEURAL_IO = $NeuralIO }
# -Setup copies the pilot videos to $LocalVideoRoot, so local runs read from the
# same place on every profile.
if ($VideoRoot) { $env:CCLAB_VIDEO_ROOT = $VideoRoot }
elseif ($VideoSource -eq 'local') { $env:CCLAB_VIDEO_ROOT = $LocalVideoRoot }
else { Remove-Item Env:CCLAB_VIDEO_ROOT -ErrorAction SilentlyContinue }
if (-not $DryRun) {
    $env:CCLAB_BENCH_RESULTS_DIR = $benchDir
    $rigName = [IO.Path]::GetFileNameWithoutExtension($RigConfig)
}
$transcript = Join-Path $logsDir 'runner_transcript.txt'

Start-Transcript -Path $transcript -Force | Out-Null
try {
    $metadata = [ordered]@{
        session_id = $SessionId
        started_local = (Get-Date).ToString('o')
        computer_name = $env:COMPUTERNAME
        computer_profile = $ComputerProfile
        participant = $SubjectId
        experimenter = $Experimenter
        eye_tracking = $EyeTracking
        neural_io = $NeuralIO
        bench_dummy = $benchDummy
        video_source = $VideoSource
        screen = $Screen
        movie_project = $movieRoot.Path
        benchmark_project = $benchRoot.Path
        rig_config = if ($rigConfigResolved) { $rigConfigResolved.Path } else { $null }
    } | ConvertTo-Json
    Set-Content -LiteralPath (Join-Path $runDir 'run_metadata.json') -Value $metadata

    if ($Setup) {
        if ($VideoSource -eq 'local') {
            $poolCsv = Join-Path $movieRoot 'video_ebm_dataset\pilot_pool.csv'
            Invoke-Checked "Copy pilot videos to $LocalVideoRoot" { Copy-PilotVideos $poolCsv $NasVideoRoot $LocalVideoRoot; $global:LASTEXITCODE = 0 }
        }
        $preflightArgs = @()
        if ($benchDummy) { $preflightArgs = @('--off-rig') }
        Push-Location $benchRoot
        try {
            Invoke-Checked 'Install Python benchmark environment' { & $uv.Source sync --locked --extra rig --extra plot }
            Invoke-Checked 'Python rig preflight' { & $uv.Source run python preflight.py --config $env:CCLAB_RIG_CONFIG @preflightArgs }
        }
        finally { Pop-Location }
    }

    if ($runBench) {
        if ($benchDummy) {
            Write-Host "`nBenchmarks run in DUMMY mode (synthetic DIO/photodiode). Results are not timing measurements." -ForegroundColor Yellow
        }
        $preflightArgs = @()
        $dummyArgs = @()
        if ($benchDummy) {
            $preflightArgs = @('--off-rig')
            $dummyArgs = @('--dummy')
        }
        Push-Location $benchRoot
        try {
            Invoke-Checked 'Install Python benchmark dependencies' { & $uv.Source sync --locked --extra rig --extra plot }
            Invoke-Checked 'Python rig preflight' { & $uv.Source run python preflight.py --config $env:CCLAB_RIG_CONFIG @preflightArgs }
            Invoke-Checked 'Python T0 DAQ benchmark' { & $uv.Source run python t0_daq.py -n $Pulses --line A --width-ms 1.0 --config $env:CCLAB_RIG_CONFIG --out $benchDir @dummyArgs }
            Invoke-Checked 'Python T1 flip benchmark' { & $uv.Source run python t1_flip.py --frames $Frames --screen $Screen --out $benchDir }
            Invoke-Checked 'Python T2 photodiode benchmark' { & $uv.Source run python t2_photodiode.py --flips $Flips --rate 50000 --pd-chan ai0 --ttl-chan ai1 --screen $Screen --config $env:CCLAB_RIG_CONFIG --out $benchDir @dummyArgs }
            Invoke-Checked 'Python T4 microbenchmark' { & $uv.Source run python t4_micro.py -n 1000000 --reps 20 --out $benchDir }

            $benchMatlab = Join-Path $benchRoot 'matlab'
            $matlabTools = Join-Path $movieRoot 'Code\cclab-matlab-tools'
            if ($benchDummy) {
                $matlabCommand = "addpath(genpath('$($benchMatlab -replace '''', '''''')')); addpath(genpath('$($matlabTools -replace '''', '''''')')); cd('$($benchDir -replace '''', '''''')'); assert(exist('Screen', 'file') ~= 0, 'Psychtoolbox is not on the MATLAB path.'); assert(exist('cclabInitDIO', 'file') ~= 0, 'cclab-matlab-tools is not on the MATLAB path.'); t0_daq('$rigName', $Pulses, 'A', 1.0); t1_flip($Frames, $Screen); t4_micro(1000000, 20);"
            }
            else {
                $matlabCommand = "addpath(genpath('$($benchMatlab -replace '''', '''''')')); addpath(genpath('$($matlabTools -replace '''', '''''')')); cd('$($benchDir -replace '''', '''''')'); assert(exist('Screen', 'file') ~= 0, 'Psychtoolbox is not on the MATLAB path.'); assert(exist('cclabInitDIO', 'file') ~= 0, 'cclab-matlab-tools is not on the MATLAB path.'); assert(license('test', 'Data_Acquisition_Toolbox'), 'MATLAB Data Acquisition Toolbox is required for T2.'); t0_daq('$rigName', $Pulses, 'A', 1.0); t1_flip($Frames, $Screen); t2_photodiode('$rigName', $Flips, 50000, $Screen); t4_micro(1000000, 20);"
            }
            Invoke-Checked 'MATLAB timing benchmark' { & $matlab.Source -batch $matlabCommand }
        }
        finally { Pop-Location }
    }

    $sourceExperimentDir = Join-Path $movieRoot 'Code\exp00_pilot_interleave'
    if ($DryRun -or $Setup) {
        $dryRunCommand = "addpath(genpath('$($sourceExperimentDir -replace '''', '''''')')); cclab = CONFI_exp00_pilot(); pool = readtable(cclab.poolFile); assert(height(pool) >= 2, 'Pilot pool needs at least two videos.'); for i = 1:height(pool), assert(exist(fullfile(cclab.filepath, 'video_all', char(pool.filename(i))), 'file') == 2, 'Missing pilot video: %s', pool.filename(i)); end; fprintf('DRY RUN OK: %s (%d videos)\n', cclab.filepath, height(pool));"
        Invoke-Checked 'exp_00 headless configuration and video check' { & $matlab.Source -batch $dryRunCommand }
    }
    elseif ($RunExperiment) {
        $safeSubjectId = $SubjectId -replace '''', ''''''
        $experimentCommand = "clearvars; clear functions; addpath(genpath('$($sourceExperimentDir -replace '''', '''''')')); cd('$($experimentDir -replace '''', '''''')'); RUN_exp00_pilot('$safeSubjectId');"
        Invoke-Checked 'exp_00 MATLAB pilot' { & $matlab.Source -batch $experimentCommand }
    }

    $script:Completed = $true
    Write-Host "`nLocal run folder: $runDir" -ForegroundColor Green
}
finally {
    Stop-Transcript | Out-Null
}

if ($ArchiveRoot -and $script:Completed) {
    $archiveDir = Join-Path $ArchiveRoot $SessionId
    Invoke-Checked "Archive run to $archiveDir" { Copy-RunToArchive $runDir $archiveDir }
    Write-Host "Archived run folder: $archiveDir" -ForegroundColor Green
}

if (-not $script:Completed) { exit 1 }
Write-Host 'Rig workflow completed.' -ForegroundColor Green
