# Video Project — Monkey Movie Free-Viewing Paradigm

Eye-tracking task where a monkey holds fixation, watches a movie, gets a juice
reward. Built on MATLAB + Psychtoolbox (PTB) + EyeLink. Started as S. Novik's
rotation project (based on O. Soyuhos' 2025 fixation-training code).

## Layout

```
Video project/
├── Code/
│   ├── RUN_freeviewingTraining_movie.m   ← run this
│   ├── CONFI_freeviewingTraining_movie.m ← all params
│   ├── pseudorandomization.m             ← movie-order picker
│   ├── isaac_reward.png / wennie_reward.png  ← reward-screen images
│   └── cclab-matlab-tools/               ← lab MATLAB utilities (git submodule)
├── Data/
│   └── Pilot data/demo_2026-03-05_1439/
│       ├── demo_2026-03-05_1439.mat      ← Results table + config
│       └── demo.edf                      ← raw EyeLink recording (9.4 MB)
├── video_ebm_dataset/                    ← dataset metadata (videos gitignored)
│   ├── dataset_licensing_citation.md     ← license + required citations
│   ├── MANIFEST.csv                      ← expected files per subfolder (for verification)
│   ├── Machado et al. 2011 Video Content.csv
│   ├── Bliss-Moreau, Machado, & Amaral, 2013 Video Rating.csv
│   ├── video_all/    (gitignored — 1200 .mpg files)
│   ├── video_nature/ (gitignored)
│   ├── video_social_directed/ (gitignored)
│   ├── video_social_undir/    (gitignored)
│   ├── video_boundary/        (gitignored)
│   └── video_clipped/         (gitignored)
├── paths.cfg.template                    ← copy to paths.cfg and set your NAS mount
└── readme_snovik.docx                    ← original rotation notes
```

**Movies are NOT in this repo.** They live on the lab NAS under
`\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset`,
which must contain subfolders `video_all/`, `video_nature/`, `video_social_directed/`,
`video_social_undir/`. See `video_ebm_dataset/MANIFEST.csv` for the full expected
file list and `dataset_licensing_citation.md` for attribution requirements.

To set your local path: copy `paths.cfg.template` → `paths.cfg` (gitignored)
and set the `filepath` line to your local mount of `video_ebm_dataset/`. See the
template for per-OS mounting instructions. `CONFI_` reads `paths.cfg` at startup.

## How to run

1. Windows rig with Psychtoolbox + EyeLink toolbox installed, EyeLink Host PC
   connected (or `dummymode=1` for mouse testing).
2. Edit `CONFI_freeviewingTraining_movie.m` (monkey, filepath, timing).
3. Run `RUN_freeviewingTraining_movie` in MATLAB. Enter subID (≤8 chars) at the
   dialog — this is the EDF filename.
4. If real EyeLink: does camera setup / 9-point calibration (HV9) before start.
5. Keys during run: `ESC` quit, `PageUp` pause, `PageDown` resume.

## Trial state machine (RUN_ ... .m)

`while ~break_out` loop switching on `state`:

| State | What happens | Exit |
|---|---|---|
| `Trial_start` | draw fixation dot, log `TrialStart_N` | → Wait_for_fixation |
| `Wait_for_fixation` | poll gaze in window | in-window → Hold_fix; timeout `t_waitfixation_fp` (5s) → ITI (abort) |
| `Hold_fix` | must stay in window `t_fixation_fp` (0.8s) | held → Movie_present; broke → ITI (abort) |
| `Movie_present` | play movie. Phase 1 (first `t_fixdot_on_image`, 0.8s): movie + fixation dot, fixation enforced. Phase 2: free-view rest of movie, no dot, no fixation check | movie end → Reward; broke fixation in phase 1 → ITI (abort) |
| `Reward` | show reward image, `cclabReward(amount)`, wait `t_reward` (1s) | → ITI |
| `ITI` | grey screen `t_trialend` (1.5s), append+save Results | → Trial_start, or Exp_end when `total_success >= totalSessionSize` |
| `Pause` / `Exp_end` | paused screen / break loop | |

Key detail: reward requires holding fixation only through phase-1 (dot-on-movie),
NOT the whole movie. Phase 2 is genuine free viewing.

### Fixation check (`checkFixation`)
Real mode: `Eyelink('NewestFloatSample')`, picks eye via `eyeUsed+1` (binocular
forced to right/index-2). Dummy mode: `GetMouse`. In-window = gaze inside square
of half-width `windowSize` deg centered on fixation point. Note: **square window,
not circular** despite "radius" naming.

### Degrees → pixels
```
ppcm = screenXpixels / screenWidth        % px per cm
ppd  = 2*obs_dist*ppcm*tan(pi/360)        % px per degree
```
All deg params (fp_x, fp_y, fpr, windowSize, rewardImageDimDeg) → px via `ppd`.

### Movie loading
All movies pre-opened before the trial loop via `Screen('OpenMovie', window,
fname, 4)` (async flag 4), textures cached in `movieTextures{}`. Each scaled to
full screen height, centered horizontally (`movieDstRects{}`). Frame loop uses
`GetMovieImage` / `DrawTexture` / `Flip` / `Close`.

## Movie selection / randomization

`pseudorandomization(n_per_category, filepath)`:
- Picks `n_per_category` random `.mpg` from each of Nature / Social_directed /
  Social_notdirected.
- Interleaves so every consecutive block of 3 has one of each type, order
  shuffled within the block.
- Returns `3 * n_per_category` file structs (from `dir`). Total session =
  `practiceBlockSize + 3*moviespertype`.

**Boundary videos:** not wired up. `pseudorandomization.m` has commented-out
Boundary scaffolding; to add, create a `Boundary_videos/` folder and extend the
interleave. Practice-movie path exists in RUN_ but was never used
(`practiceBlockSize=0`); the movie code may not work with it >0 (per author note).

## Config params (CONFI_ ... .m)

| Param | Pilot / default | Meaning |
|---|---|---|
| `dummymode` | 1 (code) / 0 (pilot ran real) | 0=EyeLink, 1=mouse |
| `operating_system` | "Windows11" | "MacOS" / "Linux" / "Windows11" — sets NAS fallback path if no paths.cfg |
| `useFixedSeed` / `randomSeed` | false / 1 | reproducible movie order |
| `filepath` | read from paths.cfg | movie root (auto-loaded; falls back to OS default) |
| `practiceBlockSize` | 0 | practice trials (keep 0) |
| `moviespertype` | 2 (code) / 3 (pilot) | movies per category → total = 3× |
| `t_waitfixation_fp` | 5 s | max time to acquire fixation |
| `t_fixation_fp` | 0.8 s (pilot 0.5) | required hold before movie |
| `t_fixdot_on_image` | 0.8 s (pilot 0) | dot-on-movie enforced phase |
| `t_trialend` | 1.5 s | ITI |
| `t_reward` | 1 s | reward image display |
| `windowSize` | 3 deg | fixation window half-width |
| `fpr` | 0.5 deg | fixation dot radius |
| `fp_x`/`fp_y` | 0/0 deg | fixation offset |
| `fp_color` | [0 0 0] | dot color |
| `reward` | 600 ms | juice pulse |
| `randreward`/`randper` | false / 0.8 | randomly double reward |
| `ScreenNumber` | 0 (pilot 1) | PTB display |
| `screenSize` | [1080 720] (pilot [0 0]=fullscreen) | window px |
| `SkipSyncTests` | = dummymode (auto) | PTB timing test skip — auto-enabled in dummymode since dev displays fail sync |
| `obs_dist`/`screenWidth` | 80 / 60 cm | geometry for ppd |
| `whichMonkey` | Isaac | selects reward png |
| `rewardImageDimDeg` | 6 deg | reward image size |

`durations` tuple order in saved cclab: (t_waitfixation_fp, t_fixation_fp,
t_fixdot_on_image, t_freeview, t_trialend, t_reward). `t_freeview` is defined
but unused (free-view = rest of movie length).

## Output data

Per session, code writes to `Output_freeviewingTraining/<subID>_<timestamp>/`:
- `<subID>_<timestamp>.mat` — MATLAB `table` named `Results` + `cclab` struct.
- EDF file received from EyeLink Host PC (raw gaze samples/events).

`Results` table columns (one row per trial; all times **ms relative to trial
start** unless noted):

| Column | Type | Meaning |
|---|---|---|
| `TrialNum` | double | trial index |
| `TrialType` | string | "Practice" / "Main" |
| `TrialSuccess` | double | 1 if rewarded, 0 if aborted |
| `RewardSize` | double | reward ms delivered |
| `ImageShown` | string | movie filename |
| `ImageRect` | cell | [left top right bottom] px |
| `TrialStart` | double | 0 (reference) |
| `FixStart` | double | ms when fixation acquired |
| `FixEnd` | double | ms when hold completed |
| `ImageOn` | double | ms movie onset |
| `DotOff` | double | ms fixation dot removed (phase-1 end) |
| `AbortPhase` | string | "None" / "Wait_for_fixation" / "Hold_fix" / "ImageDot" |

**EyeLink message markers** in the EDF (for alignment): `TrialStart_N`,
`FixInFP_N`, `ImageOn_N`, `DotOff_N`, `Reward_N`. EDF sample data includes
GAZE/HREF/RAW/AREA (see `file_sample_data` command in RUN_ ~line 273). Parse EDF
with EyeLink's `edf2asc` or a MATLAB EDF reader.

### Pilot data note
`demo_2026-03-05_1439.mat`: config shows `moviespertype=3` (9 movies),
`dummymode=0` (real tracking), monkey Vennie/Isaac. The `Results` table is a
MATLAB opaque object — **scipy/Python cannot read it**; open in MATLAB
(`load(...); Results`). Config is Python-readable.

## Gotchas / things to know

- Paths are **Windows/UNC** (`\\cns-nas...`, `strcat(filepath,'\Videos')`).
  Won't work as-is on Mac/Linux — hardcoded backslashes.
- Needs `cclabInitDIO('jA')` + `cclabReward` from lab's `cclab-matlab-tools`
  (not in this repo) for real reward delivery.
- `state == 'Movie_present'` comparisons use `'...'` (char) vs `"..."` (string)
  inconsistently — works in MATLAB by coercion but fragile.
- `rewardImagePath = pwd` — reward png must be in the working dir at run time.
- Fixation window is a **square**, dot is drawn as oval; naming says "radius".
- Reward only gated on phase-1 fixation, not full movie watch.
- Success counter `total_success` gates session end, but aborted trials still
  increment `total_trials` and get logged.

## Quickstart (MATLAB newcomers)

**Note:** this is a **MATLAB + Psychtoolbox** task, not Python/PsychoPy. You run
it inside MATLAB, not from a terminal.

### One-time setup
1. Install **MATLAB** (any recent version).
2. Install **Psychtoolbox** — http://psychtoolbox.org/download.html. This is the
   engine that draws to the screen and plays movies.
3. For real eye-tracking: install the **EyeLink Developers Kit** (SR Research)
   and the lab's `cclab-matlab-tools` (for `cclabReward` / `cclabInitDIO`). Not
   needed for mouse testing.

### Run it in mouse-test mode (no rig, no monkey)
Do this first to see the task work on your own laptop.

1. Open MATLAB.
2. In the **Current Folder** panel (or `cd` in the Command Window), navigate to
   the `Code/` folder of this project so it's the working directory.
3. Open `CONFI_freeviewingTraining_movie.m` in the editor. Set:
   - `dummymode = 1;`  → gaze follows your **mouse** instead of an eye tracker.
   - Copy `paths.cfg.template` → `paths.cfg` in the repo root and set `filepath`
     to a local folder of `.mpg` files (the NAS path won't work off the lab
     network). Needs `Videos/`, `Nature_videos/`, `Social_directed_videos/`,
     `Social_notdirected_videos/` subfolders.
   - `moviespertype = 1;` → short session while testing.
   Save the file (Ctrl/Cmd-S).
4. In the Command Window, type the run command **without** `.m` and press Enter:
   ```matlab
   RUN_freeviewingTraining_movie
   ```
5. A dialog asks for a subject ID (≤8 chars, e.g. `test`) — this names the output
   file. Type it, click OK.
6. The task window opens. Move the mouse into the fixation dot to "fixate", hold,
   then the movie plays.
7. Controls: `ESC` = quit, `PageUp` = pause, `PageDown` = resume.

### Common first-run problems
- **`Undefined function 'RUN_...'`** → you're not in the `Code/` folder. `cd`
  there, or add it to the path (right-click folder → *Add to Path*).
- **`Screen()` / Psychtoolbox errors, or a red screen** → PTB timing tests
  failing on a laptop. In CONFI set `SkipSyncTests = 1;` (testing only — never on
  the real rig).
- **Reward-image error** → the reward `.png` must be in the working directory;
  run from `Code/` where the images live.
- **Movie won't load** → `filepath` wrong, or missing the category subfolders, or
  files aren't `.mpg`.

### Going to the real rig
Flip `dummymode = 0;`, connect the EyeLink Host PC, set `SkipSyncTests = 0;`, and
point `filepath` at the NAS. On start it runs camera setup + 9-point calibration
before trials. See **How to run** above for the full rig checklist.
  increment `total_trials` and get logged.
