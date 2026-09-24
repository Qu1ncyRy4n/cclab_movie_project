# exp_00 pilot — PsychoPy version

Same design as `Code/exp00_pilot_interleave/` (MATLAB), built in parallel
as a stack comparison for this pilot — not a replacement, not the
"real" version. See that folder's README for the actual experiment spec
(fixation, interleave, reward, ITI); this doc only covers what's
PsychoPy-specific.

**Not runnable in this repo's nix devShell** — `psychopy` isn't in
`flake.nix` (it's not packaged in nixpkgs at all; checked 2026-09-24) and
isn't installed anywhere in this sandbox. `run_pilot.py` and `config.py`
are syntax-checked (`python3 -m py_compile`), not executed against a real
PsychoPy install. Treat this as a template to run and debug on the actual
test machine, not verified-working code.

## Setup

PsychoPy has heavy GUI/media dependencies (wxPython, ffpyplayer, etc.).
Two options:

1. **Standalone PsychoPy app** (most reliable on Windows) — install from
   the official PsychoPy site, then run this script with *its* bundled
   Python, not a separate env.
2. **pip / uv, in a real (non-nix) Python env**:
   ```bash
   pip install -r requirements.txt
   # or, once set up for uv (not done yet — see note below):
   uv pip install -r requirements.txt
   ```

You mentioned `uv` is already installed on the Windows test machine — the
natural next step is a `pyproject.toml` here instead of `requirements.txt`
so `uv run run_pilot.py` works directly. Not done yet since MATLAB testing
is first in line; say the word when it's time and this is a small change.

## Config

`config.py` mirrors `CONFI_exp00_pilot.m` field for field. The one you'll
need to change per machine: `video_dir` (or set the `CCLAB_VIDEO_DIR` env
var instead of editing the file) — must contain a `video_all/` subfolder
with the 4 pool videos.

```powershell
$env:CCLAB_VIDEO_DIR = "C:\cclab_data\video_ebm_dataset"
python run_pilot.py
```

## Running it

```bash
cd psychopy_pilot
python run_pilot.py
```

A dialog asks for a subject ID, then a window opens. `dummy_mode = True`
in `config.py` is the only mode this template actually implements — see
below.

## Known gaps (template, not finished)

- **No real EyeLink integration.** `check_fixation()` reads the mouse
  position unconditionally — there's no `pylink`-based branch analogous to
  the MATLAB side's `dummymode=0` path. Needed before this can run on the
  real rig, not just for dummy-mode testing.
- **No reward hardware integration.** The "c. reward" step shows on-screen
  text and logs `RewardSize`, but nothing actually drives a pump or TTL
  line — there's no equivalent of `cclabReward`/`cclabInitDIO` here yet.
  Fine for now since dummy-mode testing doesn't need it; would need a
  Python-side DIO library (e.g. via a NI-DAQ or Arduino bridge) before real
  data collection.
- **Video scaling is not pixel-matched to the MATLAB version.** PsychoPy's
  `MovieStim` sizing wasn't tuned to replicate the exact centered/scaled
  rect math `RUN_exp00_pilot.m` does — fine for a proof-of-stack check,
  worth revisiting before anything resembling real trials.
- **No EDF-equivalent fine-grained log.** The MATLAB side still emits
  `SegOn_`/`SegOff_` messages to the EyeLink EDF even with trial-level
  `Results` rows. This template has no equivalent per-segment timestamp
  record beyond print statements — add one if segment-level timing turns
  out to matter.

## Output

`Output_exp00_pilot/<subID>_<timestamp>/<subID>_<timestamp>.csv`, in the
same folder as `run_pilot.py`. Column names and order match the MATLAB
`Results` table exactly — `TrialNum, VideoA, CategoryA, VideoB, CategoryB,
SameCategory, SegDur_s, TimesShownBeforeA, TimesShownBeforeB,
FixAcquired_ms, InterleaveOff_ms, RewardOn_ms, AbortPhase, TrialSuccess,
RewardSize` — so either stack's output can be loaded with the same
downstream analysis code without a translation layer.
