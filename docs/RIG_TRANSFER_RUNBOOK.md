# exp_00 Rig Runbook

How code gets from the lab computer to the experiment computer, and how data
comes back. Every step is a double-click or one typed command; nothing needs
to be copied and pasted.

```text
lab computer (WSL)  --stage-->  NAS experiment_packages\exp00_<date>\
                                   |
experiment computer  <--install----+
  1_Setup_Rig  ->  2_Run_Benchmarks  ->  3_Run_Experiment
                                   |
NAS experiment_packages\runs\exp00\<timestamp>_<step>\  <--results copied automatically
```

Never run the experiment from the NAS, a USB drive, or a `\\wsl.localhost`
path. The installer copies the code to the experiment computer's local disk.

## Before the first session

- Both `lab_120` and `lab_121` use the `rig-right.txt` wiring config.
- The experiment computer needs internet the first time setup runs: it
  downloads Python 3.11 and the benchmark packages.
- [ ] **MATLAB on PATH.** On each computer, MATLAB must start from a plain
  PowerShell or Command Prompt window by typing `matlab`.
- [ ] Before interpreting timing data, confirm the photodiode and TTL loopback
  wiring and record the PASS/FAIL result.

## Part A — Lab computer: put a package on the NAS

1. Open the WSL terminal and go to the project:

   ```bash
   cd ~/dev/research/CogCtrlLab/cclab_movie_project
   ```

2. Type:

   ```bash
   ./stage_to_nas.sh
   ```

   It refuses to run if either repository has uncommitted changes (commit
   them first), pulls both repositories, and copies everything to a new folder
   on the NAS.

   **Expected last line:**
   `Portable package created: \\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\exp00_<date>`

   Staging twice on the same day creates `exp00_<date>_2`, `_3`, and so on. A
   package folder is never reused. Note the folder name it printed.

## Part B (optional) — Test the package on the lab computer

This runs the whole workflow without rig hardware: the mouse acts as gaze and
the benchmarks use synthetic hardware. Benchmark numbers from this test are
**not** timing measurements.

1. In File Explorer, open the package folder from Part A
   (`\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\exp00_<date>`).
2. Double-click **`Install-CCLabRig.cmd`**. Windows may first print
   "UNC paths are not supported"; that is harmless. At
   `Install to [C:\CCLabRig]`, type `desktop` and press Enter. The new
   `Desktop\CCLabRig` folder opens.
3. Double-click **`1_Setup_Rig.cmd`**. At the rig profile prompt, type
   `win_dummy`. Expected: `SETUP OK`.
4. Double-click **`2_Run_Benchmarks.cmd`**. Press Enter for the profile.
   At `Copy results to`, type
   `\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00_dummy` so test runs
   never mix with collection data. Expected: `BENCHMARKS DONE`.
5. Double-click **`3_Run_Experiment.cmd`**. Subject ID `dummy01`, Enter for
   the profile, and the same `exp00_dummy` folder. Hold the mouse on the
   fixation dot to start each trial; ESC ends early. Expected: `EXPERIMENT DONE`.

Delete `Desktop\CCLabRig` afterwards if you no longer need it.

## Part C — Experiment computer

### 1. Install (each time there is a new package)

1. In File Explorer, open the newest package folder under
   `\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\`.
2. Double-click **`Install-CCLabRig.cmd`** and press Enter to accept
   `C:\CCLabRig`. Expected: `INSTALL OK`, and the `C:\CCLabRig` folder opens.

Reinstalling over an existing `C:\CCLabRig` replaces the code exactly and
keeps `C:\CCLabRig\data\runs`, the saved rig profile, and `video_folder.txt`.

### 2. Point at the videos (once per computer, optional)

By default setup copies the eight pilot videos to
`C:\cclab_data\video_ebm_dataset\`. If the computer already has the dataset
somewhere else (for example on the Desktop), open
**`C:\CCLabRig\video_folder.txt`** in Notepad and add that folder's path on
its own line under the `#` header, for example:

```text
%USERPROFILE%\Desktop\Bliss-Moreau_Machado_Videos\video_ebm_dataset
```

Use the folder that contains `video_all` (or `video_all` itself); the File
Explorer address bar shows the exact path. Save and close. Setup prints
`Local videos (from video_folder.txt): ...` when it uses it, and copies in
only the pilot videos that are missing.

### 3. Set up (after each install)

Double-click **`C:\CCLabRig\1_Setup_Rig.cmd`** and enter the rig profile
(`lab_120` or `lab_121`). It is remembered for steps 4 and 5. Setup:

- copies the eight pilot videos from the NAS into the local video folder
  (`video_folder.txt`, else `C:\cclab_data\video_ebm_dataset\video_all\`),
  skipping ones already there,
- installs the Python benchmark environment,
- runs the hardware preflight (NI-DAQmx, PCIe-6351, displays),
- checks MATLAB can load the experiment configuration and all pilot videos.

Expected: `SETUP OK`. On `SETUP FAILED`, see Part E.

### 4. Benchmarks (before the session)

Confirm the photodiode is on the flashing corner and the TTL loopback is
connected, then double-click **`C:\CCLabRig\2_Run_Benchmarks.cmd`**. Press
Enter twice to accept the saved profile and the NAS results folder
`\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00`.

It takes about five minutes. Flashing squares on the stimulus monitor are the
test. Expected: `BENCHMARKS DONE`.

### 5. Experiment

Close other stimulus applications and confirm the EyeLink host and reward
hardware are connected. Double-click **`C:\CCLabRig\3_Run_Experiment.cmd`**,
then enter the allowed participant ID, experimenter/developer name, I/O modes,
reward duration, and archive destination.

Keys: Up Arrow safe-pause, Down Arrow resume, `F` abort-and-pause, `ESC` then `ESC` again within 3 seconds quit. Expected:
`EXPERIMENT DONE`.

Steps 4 and 5 are independent: either can be rerun on its own, and each run
gets its own results folder.

## Part D — Get the data back

Each run is saved locally first, in `C:\CCLabRig\data\runs\<timestamp>_<step>\`,
then copied to the NAS at `\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00\`.
The local copy is never deleted automatically; keep it until you have checked
the NAS copy.

| Folder suffix | Contains |
| --- | --- |
| `_setup` | `logs\`, `run_metadata.json` |
| `_bench` | `benchmark\` (raw `.npy`/`.csv` samples, JSON summaries), `logs\`, `run_metadata.json` |
| `_exp` | `experiment\` (EDF/MAT files), `logs\`, `run_metadata.json` |

For analysis, in File Explorer copy the whole timestamped folder from the NAS
`experiment_packages\runs\exp00` to your analysis location. Keep each folder intact: the data,
metadata, and logs belong together.

## Part E — When something fails

Every launcher ends with a short status line and pauses so the error stays on
screen. The full log is `logs\runner_transcript.txt` in the newest run folder
under `C:\CCLabRig\data\runs\`.

| Symptom | Check and fix |
| --- | --- |
| `MATLAB is not on PATH` | Add the MATLAB `bin` folder to the user `PATH` (Windows Settings → "Edit environment variables for your account"), then rerun the launcher. |
| `Pilot video on the NAS not found` | The NAS is not reachable or the dataset moved. Open `\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all` in File Explorer to check, then rerun setup. |
| `Missing pilot video` / `video_all not found` | Check the path in `C:\CCLabRig\video_folder.txt` (if set) points at the folder containing `video_all`, then rerun `1_Setup_Rig.cmd`; it copies whatever is missing. |
| `cclab MATLAB tools not found` | The package was staged without the MATLAB-tools submodule. Stage a new package with `./stage_to_nas.sh` (it initializes the submodule) and reinstall. |
| UV installation fails | Install UV from <https://docs.astral.sh/uv/> (or `winget install --id astral-sh.uv -e`), close the window, rerun setup. |
| "Install Python benchmark environment" fails | Usually no internet. If it mentions the lockfile, the package is out of date: stage and install a new one. |
| Preflight `FAIL` lines | Typical causes: NI-DAQmx driver missing, PCIe-6351 not detected (check NI MAX), only one display connected. Fix and rerun setup. |
| Benchmarks stop partway | Do not treat a failed run as timing evidence. Check the photodiode, TTL loopback, and that the stimulus monitor is screen 2. Do not set `SkipSyncTests=1` for a real timing measurement. |
| Experiment stops partway | Do not delete anything. Partial data and `error_log.txt` are under `experiment\Output_exp00_pilot\` in the `_exp` run folder. |
| NAS copy fails at the end | The local run folder is complete. Once the NAS is back, copy that whole folder to `experiment_packages\runs\exp00` in File Explorer. |

## Command-line reference

The launchers call `cclab_movie_project\run_rig.ps1`, which can also be run
directly from PowerShell:

| Launcher | Equivalent |
| --- | --- |
| `1_Setup_Rig.cmd` | `run_rig.ps1 -ComputerProfile lab_120 -Setup` |
| `2_Run_Benchmarks.cmd` | `run_rig.ps1 -ComputerProfile lab_120 -ArchiveRoot <NAS root>` |
| `3_Run_Experiment.cmd` | `run_rig.ps1 -ComputerProfile lab_120 -RunExperiment -SkipBench -SubjectId <ID> -ArchiveRoot <NAS root>` |

`-DryRun` performs only the MATLAB configuration and video check.
`-VideoSource nas -VideoRoot <path>` reads videos from the NAS for diagnosis;
do not stream a real session from the NAS.
