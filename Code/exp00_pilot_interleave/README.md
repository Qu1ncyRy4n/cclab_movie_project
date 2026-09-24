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

- **8 videos total**, not 600: `video_ebm_dataset/pilot_pool.csv` — 4
  `nature` (`00181DVD`, `00182DVD`, `00189DVD`, `00191DVD`) and 4
  `social_undir` (`foraging01-04DVD`). `social_directed` is dropped for
  now. 6 of the 8 are lab-vetted (`pilot_ready=1` in `MANIFEST.csv`);
  `00191DVD` and `foraging04DVD` are not (`pilot_ready` column in
  `pilot_pool.csv` itself tracks which) — only programmatically verified
  (right category, right duration, real file) plus a manual frame-grab
  spot check (2026-09-24), not full lab QC. Started at 2/category (4
  total) for the very first test; expanded once that worked.
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
- `nTrials` — currently 20. Was 40 at 2 videos/category; halved when the
  pool doubled to 4/category (2026-09-24) to hold per-video repetition
  roughly constant. Rough math: expected times-shown-per-video ≈
  (2 × trials-completed) / pool-size — e.g. 20 trials at ~70% completion
  ≈ 14 successes ≈ 3.5×/video across an 8-video pool, vs. ~14×/video at
  the original 40-trials/4-video settings.

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

**Default PowerShell script-execution policy blocks `.ps1` files directly**
on most machines (`UnauthorizedAccess` / `PSSecurityException` — confirmed
2026-09-24). Use the `.bat` wrapper as the primary path, not a fallback:

```powershell
cd Code\exp00_pilot_interleave
.\run_exp00_pilot.bat          # bypasses the execution policy for just
                                # this run; finds matlab.exe and launches it
```

Only try `.\run_exp00_pilot.ps1` directly if your machine already allows
unsigned local scripts.

`.\create_desktop_shortcut.ps1` drops a shortcut to this folder on the
Desktop, so it doesn't need re-navigating each session.

### If MATLAB doesn't open

**Headless config/path check first** — validates `computer_name`
resolution, `video_all/` presence, and `pilot_pool.csv` parsing with zero
Psychtoolbox dependency and no display needed at all (MATLAB's `-batch`
mode, genuinely non-interactive):

```powershell
.\run_exp00_pilot.bat -DryRun
```

If that passes but the real run still doesn't show a window, the problem
is specifically in opening the PTB display — a real experiment window
can't be headless, since showing stimuli is the whole point, but two
things are cheap to try before deeper debugging:

1. **Bypass the launcher chain entirely.** Open MATLAB directly (Start
   Menu, not through PowerShell/`.bat`), then in its Command Window:
   ```matlab
   cd('<this folder's path>')
   RUN_exp00_pilot
   ```
   This removes PowerShell, `cmd.exe`, and the `-sd`/`-r` launch flags as
   possible culprits — if it works here but not via `.bat`, the launcher
   scripts are the problem, not the experiment.
2. **Multi-monitor placement.** `ScreenNumber=0` in the `win_dummy` case
   is "the full Windows desktop area" (per PTB's own startup log on a
   multi-monitor machine) — the window may be opening somewhere off the
   visible primary display rather than not opening at all. Try
   `ScreenNumber=1` in `CONFI_exp00_pilot.m`.

## Notes from the first real run (2026-09-24, Windows, dummy mode)

Ran successfully end to end (17 of 20 trials before an intentional ESC
quit; several correct fixation-break aborts, several correct completions
with reward). A few things worth knowing if you see them again:

- **`cmd.exe` prints "UNC paths are not supported. Defaulting to Windows
  directory."`** when the repo is reached via `\\wsl.localhost\...` — this
  is cosmetic. `run_exp00_pilot.ps1` computes its own paths from
  `$PSScriptRoot`, independent of `cmd`'s current directory, so MATLAB
  still launched from the right place despite the warning. The `.bat` now
  does `pushd` instead of relying on an implicit UNC cwd, which should
  quiet the message going forward.
- **`Warning: Name is nonexistent or not a directory: Q:\home\qix\...`**
  at MATLAB startup — stale, from a previous session's `addpath` (likely
  `exp_01`'s `dev_wsl` case, once run against a mapped `Q:` drive) that
  got saved into MATLAB's persistent path. Harmless; doesn't block this
  script. Clean up with `pathtool` if it bothers you.
- **`PTB-ERROR: ... impossible stimulus onset value ...` on `Screen('Flip')`**
  — this is the same Windows-DWM-compositor beamposition-timestamping issue
  already tracked as unresolved for `lab_120`/`lab_121` in the main
  `README.md`'s Open Issues and `exp_01_spec.md`'s Still Open #7. Now
  confirmed to reproduce here too, not lab-rig-specific. Non-blocking for
  dummy-mode behavioral testing (the trial continued normally after the
  printed error) — matters for real stimulus-onset timing precision on the
  actual rig, not for this proof-of-stack pass.
- **A perceived "missed cut" in `foraging02DVD`** turned out not to be one
  — `cuts.csv` shows its one real cut at 14.98s, well outside the 0-6s
  window this pilot actually plays. Pulled frames at 2.5/3.0/3.5s directly
  (`ffmpeg -ss ... -frames:v 1`) and confirmed smooth, continuous footage
  in that window. Most likely explanation: the A/B interleave switch itself
  landed while `foraging02DVD` was on screen and read as an internal cut.
  If it happens again, note the wall-clock trial time so the exact
  clip/segment can be identified from the log instead of guessed at.

## Companion

A PsychoPy version of the same design lives at
`psychopy_pilot/run_pilot.py` — built in parallel as a stack comparison,
not a replacement. See its own README for setup and current gaps (no real
EyeLink integration yet, dummy/mouse mode only).
