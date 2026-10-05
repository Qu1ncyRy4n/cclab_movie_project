# exp_00 Rig Runbook

This is the workflow for a lab computer with WSL, a **Windows-only** experiment
computer with no GitHub authentication, and the NAS as the transfer point. WSL
is used only to prepare the package on the lab computer; it is neither required
nor used on the experiment computer. Never run the experiment from the NAS, a
USB drive, or a `\\wsl.localhost` path. Stage code there, then install it
locally on the experiment computer.

## Validation TODOs

- [ ] On the lab computer, run the optional Windows `-DryRun` check against
  the NAS videos.
- [ ] On the experiment computer, run the local-video `-DryRun` check.
- [ ] Before collection, complete one real dummy-mode session and verify its
  local and NAS run folders contain experiment data, benchmark data, metadata,
  and the transcript.
- [ ] Before interpreting timing data, confirm the T2 photodiode and TTL
  loopback wiring and record its PASS/FAIL result.

## 1. Prepare a package on the lab computer

In WSL, update both repositories and initialize the MATLAB-tools submodule:

```bash
MOVIE="$HOME/dev/research/CogCtrlLab/cclab_movie_project"
BENCH="$HOME/dev/research/research_infra/mat_vs_py_bench"

git -C "$MOVIE" status --short
git -C "$BENCH" status --short
git -C "$MOVIE" pull --ff-only
git -C "$MOVIE" submodule update --init --recursive
git -C "$BENCH" pull --ff-only

wslpath -w "$MOVIE"
wslpath -w "$BENCH"
```

Both `status` commands should be empty before staging. The final two commands
print Windows paths such as `\\wsl.localhost\NixOS\home\...`; copy those values.

Open **Windows PowerShell** on the same lab computer and create a new,
date-stamped folder on the NAS. Do not reuse an existing package folder.

```powershell
$Movie = "\\wsl.localhost\<distro>\home\<user>\...\cclab_movie_project"
$Bench = "\\wsl.localhost\<distro>\home\<user>\...\mat_vs_py_bench"
$Package = "\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\exp00_2026-10-05"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Movie\stage_rig_package.ps1" `
  -BenchSource $Bench `
  -Destination $Package
```

Expected result: `Portable package created: <NAS path>`. The package must
contain `cclab_movie_project`, `mat_vs_py_bench`, `Install-CCLabRig.ps1`, and
`Start-CCLabRig.cmd`.

### Optional lab-computer smoke test

If MATLAB and the NAS videos are reachable from the lab computer, install the
package to a disposable folder on the Desktop, then run the headless check. It
opens no PTB window, does not need the EyeLink or NI card, and verifies the
experiment configuration, pilot pool, and all eight pilot video files.
`GetFolderPath('Desktop')` resolves the real Desktop even when it is redirected
into OneDrive.

```powershell
$Package = "\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\exp00_2026-10-05"
$TestRoot = Join-Path ([Environment]::GetFolderPath('Desktop')) 'CCLabRigTest'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Package\Install-CCLabRig.ps1" `
  -InstallRoot $TestRoot

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TestRoot\cclab_movie_project\run_rig.ps1" `
  -BenchRoot "$TestRoot\mat_vs_py_bench" `
  -ComputerProfile win_dummy `
  -VideoSource nas `
  -VideoRoot "\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset" `
  -DryRun
```

Expected final line: `DRY RUN OK: ... (8 videos)`. Delete the Desktop `CCLabRigTest`
afterward if it was only used for this check.

## 2. Install and run on the experiment computer (Windows only)

### Install code locally

In Windows Explorer, browse to the NAS package folder. On the experiment
computer, open PowerShell and install directly from that package:

```powershell
$Package = "\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\exp00_2026-10-05"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$Package\Install-CCLabRig.ps1"
```

This copies code to `C:\CCLabRig`. It does not require GitHub credentials,
WSL, a Linux shell, or a WSL-mounted NAS path.

### Put the pilot videos on the local disk

For a real run, use a local video copy. The expected root is:

```text
C:\cclab_data\video_ebm_dataset\video_all\
```

Copy the eight pilot-pool videos from the NAS without transferring the full
dataset:

```powershell
$Source = "\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all"
$Destination = "C:\cclab_data\video_ebm_dataset\video_all"
$Pool = Import-Csv "C:\CCLabRig\cclab_movie_project\video_ebm_dataset\pilot_pool.csv"

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
foreach ($video in $Pool.filename) {
  Copy-Item -LiteralPath (Join-Path $Source $video) -Destination $Destination -Force
}
Get-ChildItem $Destination -Filter *.mp4 | Measure-Object
```

Use the full 600-video local copy only if a later experiment needs it.

### Headless preflight

Before using the rig, confirm the installed package finds all eight videos:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\CCLabRig\cclab_movie_project\run_rig.ps1" `
  -BenchRoot "C:\CCLabRig\mat_vs_py_bench" `
  -ComputerProfile lab_120 `
  -VideoSource local `
  -DryRun
```

Use `lab_121` instead if that is the physical rig. Do not use `win_dummy` for
a real EyeLink/reward run. The expected result is `DRY RUN OK`.

### Run the session

Close other stimulus applications, confirm the EyeLink host, reward hardware,
photodiode, and TTL loopback are connected, then double-click:

```text
C:\CCLabRig\Start-CCLabRig.cmd
```

Enter a subject ID of 1-8 letters, numbers, or underscores, then select the
physical rig profile (`lab_120` or `lab_121`). When asked for an archive
location, enter a NAS collection root, for example:

```text
\\cns-nas.ucdavis.edu\cclab\shared\rig_runs\exp00
```

The launcher runs the MATLAB pilot first, then the Python and MATLAB timing
benchmarks. It creates one timestamped subfolder under both the local
`C:\CCLabRig\data\runs\` root and the archive root. Keep the local folder
until the NAS copy has been checked.

## 3. Recover from common failures

| Symptom | Check and fix |
| --- | --- |
| `matlab.exe not found` | In PowerShell run `where.exe matlab`. If empty, add the installed MATLAB `bin` folder to the system or user `PATH`, open a new PowerShell window, then rerun. |
| `video_all not found` | Confirm `C:\cclab_data\video_ebm_dataset\video_all` exists. Rerun the eight-video copy block. For diagnosis only, run the dry check with `-VideoSource nas -VideoRoot "\\cns-nas...\video_ebm_dataset"`; do not stream a real session from the NAS. |
| `Missing pilot video` | Read the filename in the error, then copy that file from the NAS `video_all` folder to the local `video_all` folder. |
| `cclab MATLAB tools not found` | Confirm `C:\CCLabRig\cclab_movie_project\Code\cclab-matlab-tools\cclabInitDIO.m` exists. If absent, the package was staged before the Git submodule was initialized; rebuild the package on the lab computer. |
| UV installation fails | Run `winget install --id astral-sh.uv -e`, open a new PowerShell window, then rerun. |
| Benchmark preflight fails | Read `C:\CCLabRig\data\runs\<timestamp>\logs\runner_transcript.txt`. Typical causes are missing NI-DAQmx, no PCIe-6351 detected, wrong screen, or no photodiode/TTL loopback. Do not treat a failed T2 run as usable timing evidence. |
| MATLAB/PTB screen issue | Verify display numbering with the rig’s PTB setup. `exp_00` uses screen 2 for `lab_120`/`lab_121`; the benchmark uses the runner’s `-Screen 2` default. Keep them aligned. Do not set `SkipSyncTests=1` for a real timing measurement. |
| Run stops partway through | Do not delete anything. The local run folder contains `logs/runner_transcript.txt`; experiment crash handling writes partial data and `error_log.txt` under `experiment/Output_exp00_pilot/`. |
| NAS archive copy fails | The local run folder is retained. Restore NAS connectivity, then copy that complete timestamped folder manually with `robocopy /E /Z /R:3 /W:5`. |

## 4. Return data through the NAS

The preferred path is experiment computer -> NAS -> lab computer -> personal
computer. The experiment launcher already performs the first hop when an
archive root is supplied.

On the experiment computer, verify the archive has the expected directories:

```text
<archive root>\<timestamp>\experiment\
<archive root>\<timestamp>\benchmark\
<archive root>\<timestamp>\logs\
<archive root>\<timestamp>\run_metadata.json
```

On the lab computer, make a local read-only working copy for analysis:

```powershell
$Run = "2026-10-05_143000"  # replace with the actual timestamp
$Source = "\\cns-nas.ucdavis.edu\cclab\shared\rig_runs\exp00\$Run"
$Destination = "C:\CCLabData\exp00\$Run"
robocopy $Source $Destination /E /Z /R:3 /W:5 /COPY:DAT
if ($LASTEXITCODE -gt 7) { throw "Copy failed: $LASTEXITCODE" }
```

On a personal computer, copy the same NAS run folder to an analysis location
with the same `robocopy` command, or download it through the lab-approved NAS
client. Preserve the entire timestamped folder: the EDF/MAT files, raw `.npy`
and `.csv` benchmark samples, JSON summaries, metadata, and logs belong
