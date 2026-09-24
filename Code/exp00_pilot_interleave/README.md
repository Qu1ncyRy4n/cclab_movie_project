# exp_00 — the tiny pilot

Deliberately the simplest possible interleave task, built to get *something*
running on the stack this week rather than settle the exp_01 design
questions first. See `docs/interleave_design_options_2026-09-24_0951.md`
and its demo for that larger design-space discussion — this pilot
intentionally ignores almost all of it.

## What it does

```
1. Startup
2. Trial:
   a. Fixation dot — hold 0.85 s to proceed
   b. Pick 2 DISTINCT videos at random (same or different category —
      not controlled), interleave A/B/A/B... at segDur seconds each,
      6 s of each clip total, from t=0
   c. Unconditional reward
   d. ITI — blank, 2 s (or 3 s)
   e. repeat from 2a until nTrials
3. Shutdown
```

## Why this is so much smaller than exp_01

- **4 videos total**, not 600: `video_ebm_dataset/pilot_pool.csv` —
  `00181DVD`, `00182DVD` (nature) and `foraging01DVD`, `foraging02DVD`
  (social_undir), all already hand-vetted (`pilot_ready=1` in
  `MANIFEST.csv`). `social_directed` is dropped for now.
- **No de Bruijn balancing, no `buildSequence.m`.** Every trial draws 2
  videos live, uniformly at random from the 4 — same-category and
  cross-category pairs both happen, unbalanced. Good enough to get
  something running; revisit if it matters once there's real data.
- **No per-segment fixation dot.** exp_01's `t_fix_between` is gone —
  once the trial's initial 0.85 s hold passes, the interleave plays
  straight through.
- **No `min(A,B)` trial-length rule.** Every pool video is >=7.0 s
  (`durations.csv`), so "6 s of each clip from t=0" is always safe with
  margin — the whole point of the >=6s filter mentioned in the spec turned
  out to be a no-op against this dataset (nothing in nature/social_undir is
  under 7s), which is worth knowing before assuming the filter is doing
  real work.
- **One row per trial**, not per segment (`Results` table). Per-segment
  `SegOn_/SegOff_` EyeLink messages still go to the EDF if finer timing is
  ever needed.

## Familiarity — logged, not controlled

Selection doesn't avoid repeats or balance exposure. What it does do:
`TimesShownBeforeA` / `TimesShownBeforeB` in `Results` record how many
times that exact video had already been shown to this subject *before*
this trial, so repetition/familiarity effects are reconstructable later
without having to control for them now.

## Config knobs worth trying (`CONFI_exp00_pilot.m`)

- `segDur` — 2 or 3 s. Both worth a look; not a settled choice.
- `durations.t_trialend` — ITI, 2 or 3 s.
- `nTrials` — currently 40, arbitrary.

## Running it

```matlab
cd Code/exp00_pilot_interleave
RUN_exp00_pilot
```

Same `computer_name` / `dummymode` / `video_source` machinery as exp_01 —
see `CONFI_exp00_pilot.m`. Needs `video_ebm_dataset/pilot_pool.csv` (repo
root) and the 4 videos present under `video_all/`.

### From Windows PowerShell, dummy mode

`computer_name` defaults to `'win_dummy'` — a case added for exactly this:
mouse-as-gaze testing on any Windows machine, no path editing needed
(`matlab_path` is derived from the script's own location, not hardcoded).
`video_source` defaults to `'local'`, pointed at a confirmed-present local
copy (`C:\Users\qmryan\Desktop\Bliss-Moreau_Machado_Videos\video_ebm_dataset`,
all 4 pool videos verified present there 2026-09-24) — no NAS/VPN
dependency. Repoint `filepath_local` in `CONFI_exp00_pilot.m` if running
as someone else, or switch `video_source` back to `'nas'`.

**Where to find things from PowerShell**, if this repo is only cloned
inside WSL (as it is on this dev machine) rather than natively on Windows:
`matlab.exe` is already on `PATH` (`C:\Program Files\MATLAB\R20XXx\bin`),
and the repo itself is reachable at
`\\wsl.localhost\<distro>\home\<user>\...\cclab_movie_project` — check
your distro name with `$env:WSL_DISTRO_NAME` if unsure (it's `NixOS` on
this dev machine). Running MATLAB against files over that bridge works;
just don't expect NTFS-native speed for anything I/O-heavy.

```powershell
cd Code\exp00_pilot_interleave
.\run_exp00_pilot.ps1          # finds matlab.exe on PATH and launches it;
                                # prints manual instructions if not found
```

If PowerShell blocks the script (unsigned-script policy), double-click
`run_exp00_pilot.bat` instead — it bypasses the policy for just that one
run, not system-wide.

`.\create_desktop_shortcut.ps1` drops a shortcut to this folder on the
Desktop, so it doesn't need re-navigating each session.

## Companion

A PsychoPy version of the same design lives at
`psychopy_pilot/run_pilot.py` — built in parallel as a stack comparison,
not a replacement. See its own README for setup and current gaps (no real
EyeLink integration yet, dummy/mouse mode only).
