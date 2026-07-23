# Video Project — Monkey Movie Free-Viewing Paradigm

Eye-tracking task where a monkey holds fixation, watches a movie, gets a juice
reward. Built on MATLAB + Psychtoolbox (PTB) + EyeLink. Started as S. Novik's
rotation project (based on O. Soyuhos' 2025 fixation-training code).

## Layout

```
Video project/
├── Code/
│   ├── RUN_freeviewingTraining_movie.m   ← run this
│   ├── CONFI_freeviewingTraining_movie.m ← all params (set computer_name here)
│   ├── pseudorandomization.m             ← movie-order picker
│   ├── isaac_reward.png / wennie_reward.png  ← reward-screen images
│   └── cclab-matlab-tools/               ← lab MATLAB utilities (git submodule)
├── encode_mp4.sh                         ← re-encode .mpg → H.264 .mp4 (run from WSL)
├── Data/
│   └── Pilot data/demo_2026-03-05_1439/
│       ├── demo_2026-03-05_1439.mat      ← Results table + config
│       └── demo.edf                      ← raw EyeLink recording (9.4 MB)
├── video_ebm_dataset/                    ← dataset metadata (videos gitignored)
│   ├── dataset_licensing_citation.md     ← license + required citations
│   ├── MANIFEST.csv                      ← expected files per subfolder (for verification)
│   ├── Machado et al. 2011 Video Content.csv
│   ├── Bliss-Moreau, Machado, & Amaral, 2013 Video Rating.csv
│   ├── video_all/    (gitignored — 1200 .mp4 files, re-encoded from original .mpg)
│   ├── video_nature/ (gitignored)
│   ├── video_social_directed/ (gitignored)
│   ├── video_social_undir/    (gitignored)
│   ├── video_boundary/        (gitignored)
│   └── video_clipped/         (gitignored)
└── readme_snovik.docx                    ← original rotation notes
```

**Movies are NOT in this repo.** They live on the lab NAS under
`\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset`,
which must contain subfolders `video_all/`, `video_nature/`, `video_social_directed/`,
`video_social_undir/`. See `video_ebm_dataset/MANIFEST.csv` for the full expected
file list and `dataset_licensing_citation.md` for attribution requirements.

To configure a machine: set `computer_name` at the top of
`CONFI_freeviewingTraining_movie.m` to match the machine, then add a `case` to
the switch block with its `dummymode` and `filepath`. Lab rigs auto-get
`dummymode=0`; all others get `dummymode=1`.

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
- Reads `video_ebm_dataset/MANIFEST.csv` (from repo, not from video path) to
  determine which files in `video_all/` belong to each category.
- Picks `n_per_category` random `.mpg` per category (nature / social_directed /
  social_undir), interleaves so every consecutive block of 3 has one of each
  type in random order.
- Returns a `3*n_per_category × 1` struct array with fields:
  - `.filepath` — full path to the `.mpg` file
  - `.name` — filename only (for logging / Results table)
  - `.category` — `'nature'` | `'social_directed'` | `'social_undir'`
- Only `video_all/` needs to exist on disk. No per-category subfolders needed.

**Boundary videos:** not wired up. To add: extend MANIFEST with a `video_boundary`
column and add a 4th category in `pseudorandomization.m`.

**Practice block:** vestigial from the image-paradigm predecessor. `practiceBlockSize`
must stay `0` — the practice path still uses `dir()` structs which are incompatible
with the new trial struct format. See open issues below.

## Config params (CONFI_ ... .m)

| Param | Pilot / default | Meaning |
|---|---|---|
| `computer_name` | 'dev_wsl' | which machine — sets `dummymode` and `filepath` automatically; add a `case` for new machines |
| `dummymode` | auto (0 for lab rigs, 1 otherwise) | 0=EyeLink, 1=mouse |
| `useFixedSeed` / `randomSeed` | false / 1 | reproducible movie order |
| `filepath` | auto from `computer_name` | video root (set via the switch block in CONFI) |
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

- Needs `cclabInitDIO('jA')` + `cclabReward` from lab's `cclab-matlab-tools`
  (submodule at `Code/cclab-matlab-tools/`) for real reward delivery.
- `state == 'Movie_present'` comparisons mix `'...'` (char) and `"..."` (string)
  — works in MATLAB by coercion but fragile.
- `rewardImagePath = pwd` — reward `.png` must be in the working directory at
  run time; always run from `Code/`.
- Fixation window is a **square**, dot is drawn as oval; naming says "radius".
- **Success definition:** `TrialSuccess=1` means the monkey held fixation through
  phase 1 only (`t_fixdot_on_image` = 0.8 s). Phase 2 is free-viewing with no
  fixation requirement. A monkey can watch a lot of movie time on "failed" trials
  — consider this when interpreting viewing-time analyses.
- `total_success` gates session end; aborted trials still increment `total_trials`
  and are logged. The same movie retries until it earns a reward.

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
3. Open `CONFI_freeviewingTraining_movie.m` in the editor. At the top:
   - Set `computer_name` to your machine (e.g. `'macbook_pro'`). If it's not
     listed, add a `case` to the switch block with `dummymode = 1` and the path
     to a local folder of `.mpg` files inside a `video_all/` subfolder.
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
- **Movie won't load** → `filepath` in CONFI wrong, or `video_all/` missing or
  empty, or files aren't `.mp4`. MANIFEST.csv is read from the repo — you do not
  need to copy it alongside the videos.

### Going to the real rig
Set `computer_name = 'lab_120'` (or `'lab_121'`) in CONFI — this automatically
sets `dummymode=0` and points `filepath` at the NAS. Connect the EyeLink Host PC;
on start it runs camera setup + 9-point calibration before trials. See **How to
run** above for the full rig checklist.

## Open issues / TODO

- [ ] **Practice block incompatible with new struct** — `practiceBlockSize > 0`
  will crash because practice files are raw `dir()` structs; needs to build
  `.filepath/.name/.category` structs instead. Low priority: practice is unused.
- [ ] **Results table not yet updated** — `VideoCategory`, `VideoDuration_s`, and
  `VideoWidth`/`VideoHeight` are not yet captured in the Results table. These are
  free from `Screen('OpenMovie')` return values and worth adding before real data
  collection.
- [ ] **Console debug print not yet added** — wanted a per-trial category print to
  MATLAB command window (e.g. `[Trial 3] category: nature | file: 00181DVD.mp4`).
- [ ] **`TrialType` column is always "Main"** — "Practice" path is dead; column
  is vestigial. Either remove or repurpose.
- [ ] **Move encoded videos to NAS** — re-encoding .mpg → .mp4 in progress (see
  `encode_mp4.sh`). Once complete, copy `video_all_mp4/` contents to NAS
  `video_all/` and set `computer_name = 'lab_120'` in CONFI.
- [ ] **Windows shortcut to repo** — create a `.lnk` on the lab Desktop pointing to
  the repo root so it's easy to find on the Windows machine.
- [ ] **Boundary video support** — not wired up. Add `video_boundary` column to
  MANIFEST, extend `pseudorandomization.m` with a 4th category and group size.

## Devlog

### 2026-07-23
- **Video format switched to H.264 `.mp4`** — original `.mpg` files (MPEG-2) are
  being re-encoded using `encode_mp4.sh` (ffmpeg, CRF 20, `libx264`, `preset slow`).
  Originals remain on NAS untouched. Code updated to scan for `*.mp4`; MANIFEST
  matching is now extension-agnostic (basename only) so MANIFEST.csv needs no update.
  Some source files have minor MPEG-2 decode warnings (`ac-tex damaged`) — these
  reflect pre-existing corruption in the original rip, not encode errors.
- **`matlab_path` added per machine** — CONFI switch now sets both `filepath`
  (videos) and `matlab_path` (Code/ folder), which are used for `addpath` so
  MATLAB can find project files and `cclab-matlab-tools` automatically.
- **Machine config simplified** — `paths.cfg` / `paths.cfg.template` system removed.
  `CONFI` now has a single `computer_name` variable at the top; a `switch` block
  sets both `dummymode` and `filepath` automatically. Lab rigs (`lab_120`,
  `lab_121`) get `dummymode=0` (real EyeLink); all other machines get `dummymode=1`
  (mouse). To add a new machine, add one `case` to the switch.

### 2026-07-22
- **`paths.cfg` system introduced** (superseded 2026-07-23 — see above).

### 2026-07-16
- **`pseudorandomization.m` fully rewritten** — no longer reads from per-category
  subfolders (`video_nature/` etc.). Now reads only `video_all/` and filters using
  `MANIFEST.csv`. MANIFEST is resolved relative to the script file (in the repo),
  so videos and manifest can live in separate locations (Desktop vs. repo).
- **New trial struct** — `pseudorandomization` now returns structs with
  `.filepath` (full path), `.name` (filename), `.category` ('nature' |
  'social_directed' | 'social_undir') instead of raw `dir()` structs.
- **`playOrder` removed** — was a vestigial identity array (`1:N`); replaced
  `idx = playOrder(currentPtr)` with `idx = currentPtr` directly.
- **`paths.cfg` updated** to Desktop video path for current development machine
  (`C:\Users\qmryan\Desktop\Bliss-Moreau_Machado_Videos\video_ebm_dataset`).
- **Fixed** `Screen('OpenMovie')` crash — run script was looking in `video_all/`
  for files selected from category subfolders; now uses `.filepath` from the
  trial struct directly.

### 2026-07-14
- Repo restructured: `Pilot data/` → `Data/Pilot data/`, `video_ebm_dataset/`
  folder added with dataset metadata (CSVs, manifest, license).
- Video folder names standardised (`Nature_videos/` → `video_nature/`, etc.),
  path construction switched from `strcat`+backslash to `fullfile()` for
  cross-platform compatibility.
- `paths.cfg` system added for gitignored local NAS mount config.
- `cclab-matlab-tools` added as git submodule under `Code/`.
