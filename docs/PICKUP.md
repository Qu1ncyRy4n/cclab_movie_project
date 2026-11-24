# Pickup — exp_01 transitions

State of play as of **2026-09-16**, written so another machine (or another
person) can continue without the conversation that produced it.

---

## 2026-10-26 13:53 — next: data validation / sanity checks for exp00

Since 09-24, exp00 moved from dummy-mode testing to real data. Session plans
are locked, curation is done (commits through 2026-10-11), and there is one
full session:

- **Vennie 2026-10-07** — `Data/Pilot data/2026-10-07_130943_exp/`. 180/180
  trials ran and all 180 succeeded. EDF (101 MB), `.mat`, `event_log.csv`,
  `session_plan.csv`. The plan copy in `Output/` is byte-identical to the one
  in `session_plan/`.
- **2026-10-05_165406_exp** — a short 9-trial run in
  `~/dev/research/data/`. This is the default `RUN_ID` in
  `data_analysis/validate_exp00_run.ipynb`.
- The existing notebook only checks that files exist, prints summary means,
  and counts EDF sample gaps. It does not validate the data.

Two things looked suspicious:
- The transcript reports **14,234 of 67,750 flips missed their deadline
  (21%)**.
- ~~180 `Reward` events vs 179 successes~~ — false alarm: "success so far=179"
  in the transcript is printed *before* trial 180 runs.

### 2026-10-27 — results for checks 12, 5, 8, 1 (Vennie 10-07)

Script: `data_analysis/qc_exp00.py <run_dir>`. It is stdlib only, takes
about 2 s, writes `derived/qc_report.json`, and exits 1 on a hard failure.
Before running it, `derived/trials_from_mat.csv` has to come from MATLAB
(`/Applications/MATLAB_R2025a.app/bin/matlab -batch`, see notebook) and the
`.asc` from `edf2asc -y`. **All hard checks pass.**

- **12 — track loss:** 3.9% of samples are lost across the whole file. The
  median per trial during movies is 1.2%, max 8.6%; no trial exceeds 20%.
  Loss rises slightly over the session (1.3% → 1.8%). 1,097 blinks.
  Confirmed the notebook bug: its regex skipped all 142,305 lost-sample
  lines. Fix the notebook or retire it in favour of the script.
- **5 — counts and order:** EDF, `event_log` and Results agree exactly: 180
  trials, 1080 SegOn/Off, 180 rewards, and `SessionEnd successes=180`.
  Every trial has segments in order (1A,1B,2A,2B,3A,3B) in both EDF and
  `event_log`, with FixInFP before the movie. FixInFP fires 1–38× per trial
  (145 trials once), i.e. fixation re-acquired after breaks.
- **8 — timing:** segment *durations* are fine: median 2009 ms, range
  1999–2026, none off by more than 100 ms. **The problem is the gap between
  segments.** SegOff→next SegOn has a median of 333 ms (range 99–733), so
  trials last 13.5 s instead of 12 s. During that gap the previous movie's
  last frame stays frozen on screen. This is a stimulus confound at every
  A↔B switch. Gap ≈ **88 ms + 86 ms per second the target sits past the
  previous keyframe** (r = 0.77, n = 900). The pattern looks the same
  across videos; the cause is keyframe distance.
  - That slope is indirect evidence that **seeks are accurate**: the decoder
    rolls forward to the exact target and does not snap to a keyframe.
    `test_seek` is still the proof.
  - Fix: dense keyframes (step 3 below, `-g 25`) should cap the gap near
    ~90–130 ms everywhere. Alternatively, draw a gray/fixation frame during
    the seek so the frozen frame is at least deliberate. The 10-08
    `SeekToFirstFrame_ms` diagnostic postdates this run, so the next session
    will log it directly.
- **1 — plan fidelity:** 0 mismatches. Plan, Results and `PairSelected`
  agree on videos, categories, SameCategory and Condition for every
  trial, and TimesShownBeforeA/B matches a recount. Design: NN/NS/SS 60
  each, 36 videos shown exactly 10× each. Start_s cannot be verified from
  the data because the actual seek position isn't logged.

Not applicable: the 10-05 run predates `event_log.csv`/plans, so the script
doesn't run on it.

**Decision 2026-10-27: switch-gap fix DEFERRED.** We analyze the data as
collected. Consequences for analysis:
- Treat each SegOff→SegOn gap (99–733 ms, frozen last frame of the
  previous movie) as its own epoch. Don't pool it with either movie's
  segment, and use EDF SegOn/SegOff as the true boundaries, not the
  nominal 2 s grid.
- Gap length is confounded with segment index (seg 1 ≈ 125 ms, seg 3
  ≈ 400 ms). Check any effect by segment position against this before
  interpreting it.
- Revisit (re-encode with `-g 25` or add a gray frame) before any new
  collection.

**Next:** neural preprocessing — see `docs/PREPROCESSING.md` (waiting on
the NAS and on Brinda's probe config). Then `test_seek`, then checks 13–16 (calibration: the ASC has `!CAL` points but
no VALIDATE result lines, so calibration may never have been validated).

**Plan.** Make the notebook driven by `RUN_ID`, put an assert on each
check, write `derived/qc_report.json`, and move the parsing into one small
`qc_exp00.py`. Run it on Vennie 10-07 first, then 10-05.

**A. Did the plan get executed?**
1. Each trial matches its row in `session_plan.csv`: VideoA/B, Condition
   and StartA_s/StartB_s, checked against Results and the `PairSelected`
   lines in `event_log`.
2. The hash of the plan that ran matches `approved_session_plan_metadata.json`.
3. Design balance in what actually played: counts per Condition and per
   video, the PairRepetition distribution, and TimesShownBeforeA/B
   recounted from the plan.
4. Start_s + 6 s ≤ the duration in `durations.csv`. Optionally flag clip
   windows that straddle a cut in `cuts.csv`.

**B. Do the three event streams (EDF, `event_log`, Results) agree?**
5. Event counts match: 180 TrialStart, 1080 SegOn/Off (6 per trial), and
   Reward only on successful trials. Explain the extra Reward.
6. Event order within each trial: TrialStart → FixInFP → Seg1A → Seg1B → … →
   Seg3B → Reward. No missing or duplicated segments, and A/B alternation
   matches the design.
7. Clocks agree: regressing EDF message times against Results timestamps
   gives a slope of about 1 with small residuals.

**C. Was the timing right?**
8. SegOff − SegOn ≈ 2.000 s. Plot the distribution per trial and per video,
   and check whether the 21% flip misses cluster on particular videos or
   seek points.
9. A→B switch latency, and the cumulative interleave length against the
   12 s nominal.
10. ITI ≈ 2 s and reward image ≈ 1 s.
11. Seek accuracy (`test_seek`, see "Do these next" step 1 below) is
    **still unchecked**. If seeks snap to keyframes, StartB is wrong with no
    error raised. Settle this before trusting check 1.

**D. Is the eye data usable?**
12. **The notebook's loss check can never fail.** In ASC files, lost samples
    are written as `.`, and the sample regex skips those lines, so
    `missing_x_or_y` is always 0. Parse `.` as NaN and also count
    EFIX/ESACC/EBLINK events.
13. Track loss and blinks per trial during movie playback, and over the
    session (to see fatigue). Set a threshold for excluding trials.
14. Calibration: read the CAL/VALIDATE lines (average and max error). Check
    that DISPLAY_COORDS matches the screen resolution, and that gaze falls
    mostly on the movie rectangle.
15. Gaze is inside the fixation window just before FixInFP. Main-sequence
    plot (saccade amplitude vs. peak velocity) and fixation-duration
    histogram.
16. Read the sample rate from the RECCFG line instead of hardcoding
    gap > 2 ms.

**E. Hardware and edge cases**
17. TTLs: 2 lines per segment edge in the transcript. Count them. Neural
    alignment waits on the export, and Brinda still needs to confirm that
    the Neuropixel side tolerates the pulse density (see loose ends).
18. Reward count against TrialSuccess, and RewardSize constant at 400 ms.
19. The one unsuccessful trial: check its AbortPhase, that it got no reward,
    and whether it has partial segments. Also check pause/F-abort lines in
    the transcript, and that nothing from
    `Output_exp00_pilot/crash_2026-10-05_1508` leaked into analysis.
20. Metadata is consistent with the folder name. Check that the local video
    copy matches the NAS (count + checksum).

**Do first:** 12, 5, 8, 1. These are the most likely to find real problems.

---

## 2026-09-24 — pivot: exp_00, a deliberately tiny pilot, built alongside exp_01

Everything below this point is still accurate for `exp_01_transitions` and
still the deeper design work — see `exp_01_spec.md` and
`docs/interleave_design_options_2026-09-24_0951.md` (design-space matrix +
interactive demo at `docs/demos/interleave_options_demo.html`) for that.
But real data collection is starting from something much smaller first:

- **`Code/exp00_pilot_interleave/`** (MATLAB) — 4 hand-vetted videos (2
  `nature`, 2 `social_undir`, from `MANIFEST.csv`'s `pilot_ready` column),
  no de Bruijn balancing, no `buildSequence.m`, fixation once per trial
  then a fixed interleave, unconditional reward. Own README covers the
  design and why it's this simple.
- **`psychopy_pilot/`** (Python) — the same design, built in parallel as a
  stack comparison. Template only — not run against a real PsychoPy
  install, no EyeLink/reward-hardware integration yet. Own README covers
  gaps.
- **`video_ebm_dataset/pilot_pool.csv`** — the shared 4-video pool both
  stacks read from.
- Rationale: too many open design questions (segment length, matching
  criterion, familiarity/repetition, PI's exact "interleaved" requirement)
  to settle any of them without first seeing real behavior. This pilot logs
  `TimesShownBeforeA/B` for future familiarity analysis but doesn't control
  for it yet.
- **First real run: done, 2026-09-24, Windows dummy mode — worked.** Ran
  end to end (fixation, interleave, reward, ITI, correct aborts and
  completions logged). Three cosmetic/known-issue warnings encountered,
  none blocking — see "Notes from the first real run" in
  `Code/exp00_pilot_interleave/README.md`. Pool expanded from 2 to 4
  videos/category and `nTrials` halved (40→20) afterward to control
  per-video repetition as the pool grew — same README.
- **Next**: PsychoPy side hasn't been run yet (still template-only, see
  `psychopy_pilot/README.md`'s Known gaps). Real EyeLink/reward-hardware
  integration still needed on both stacks before this moves past
  dummy-mode testing.

---

## Where things stand

`Code/exp01_transitions/` is a complete, runnable experiment: playlist-driven
free viewing across video transitions. It has never been run against real
videos. Two questions gate real data collection, both listed under
**Do these next**.

What was settled, with evidence in the repo:

- **All 300 social videos are exactly 30 s**; 592 of 600 videos overall are
  30 s. Eight nature videos are short (7.0 s to 29.5 s) and exclude themselves
  automatically. Evidence: `video_ebm_dataset/durations.csv`.
- **Clips are seeked in place, not split to disk.** No new files, no writes to
  the NAS, and `MANIFEST.csv` needs no new rows. Segment provenance is recorded
  per row in the results table instead.
- **Transitions and interleaving are one mechanism**, not two paradigms — the
  same segment playlist with different boundaries. One playback loop serves
  both (`cclab.mode`).

**Settled 2026-09-24** (was "believed but not yet established" at n=1 — see
`docs/cuts_analysis.md` for the full writeup):

- `cuts.csv` now exists — all 600 videos, built and committed.
- The n=1 belief was wrong on the directed/undirected split. **Directed
  videos are not continuous**: `social_directed` has the same zero-cut rate
  (10%) as `social_undir`, and the same median inter-cut gap (6.01 s) as
  `social_undir`. The spec's original "3 × 10 s" assumption was also wrong,
  same conclusion as before, now on real evidence instead of one file.
- Gaps vary a lot *across* a category (CV 0.6–0.8) but are often very regular
  *within* one video — `social_directed` especially so (near-metronomic when
  cuts occur), which may mean those are multi-camera switch artifacts rather
  than content cuts; worth checking against source material before treating
  them as meaningful transitions.
- `nature` is its own thing: fewer cuts (25% zero-cut), longer/less regular
  gaps (~7.9 s median, CV 0.78) than either social category.
- `clipDur = 6` is defensible as a single constant for the social categories;
  a per-video/per-category value would track the real structure better if
  the pipeline can support it. Decision not yet made — see `exp_01_spec.md`
  open question #1.

---

## Do these next, in this order

### 1. Settle seek accuracy — BLOCKING, ~5 min, needs MATLAB + Psychtoolbox

The dataset is encoded with x264 defaults, so keyframes sit **~8.34 s apart**
(measured: 0.00, 8.33, 16.67, 25.00). Every segment after the first is reached
by seeking mid-file. If Psychtoolbox snaps seeks to the nearest keyframe, then
asking for 2.5 s silently yields 0 s and **interleave mode plays entirely the
wrong footage with no error raised**.

```matlab
cd Code/exp01_transitions
test_seek
```

Needs no NAS and no monkey. It seeks into a bundled 30 s test pattern that has
the elapsed second burned into the picture and the same sparse GOP as the real
data, then saves each frame.

- requested 13.7 → picture reads **13** → accurate seek, the design holds
- requested 13.7 → picture reads **8** → keyframe snap, go to step 3

**Write the answer into `exp_01_spec.md`.** Everything downstream depends on it.

### 2. Build the cut catalog — DONE 2026-09-24, see `docs/cuts_analysis.md`

Produces `video_ebm_dataset/cuts.csv`: keyframe positions and scene-cut
positions for all 600 videos.

**This reads every byte of the 5.5 GB dataset.** Measured cold-read throughput
over the VPN is ~430 KB/s → about **3.6 hours**. On the lab LAN it is roughly
**2 minutes**. Run it where the files are.

```bash
# verify the tooling first — builds its own test video, touches no data
bash catalog_cuts.sh --selftest        # expect: selftest cuts: [2.000] ... selftest OK

VID=/mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all
ls "$VID"/*.mp4 | wc -l                # expect 600

bash catalog_cuts.sh "$VID"
```

The videos directory is a **positional argument to the script** — nothing to do
with `CONFI_exp01_transitions.m`, which only matters to MATLAB. Written out in
full, that last line is:

```bash
bash catalog_cuts.sh /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all
```

`cuts.csv` is written inside the repo regardless of where the videos live, so
the repo has to be cloned on whatever machine runs this.

Resumable — `cuts.csv` is its own progress ledger, so a dropped mount costs one
file, not the run. For a long run: `nohup bash catalog_cuts.sh "$VID" > catalog.log 2>&1 &`
(if you background it this way, don't `pgrep -f "catalog_cuts.sh"` to wait for
it from a wrapper script that itself contains that string in its command
line — it'll match itself and never exit. Wait on the PID instead.)

Ran on the lab machine (local disk, not NAS/VPN): 600/600 in ~5 minutes.
`cuts.csv` is committed. Joined against `MANIFEST.csv` by category with
`video_ebm_dataset/analyze_cuts.py` (needs `nix develop` for pandas — bare
`python3` isn't on `PATH` on this machine). **Full writeup:
`docs/cuts_analysis.md`.** Short version: the n=1 "directed = continuous"
belief was wrong; `clipDur = 6` is defensible for the social categories but
`nature` behaves differently. `cclab.clipDur` decision still open — see
`exp_01_spec.md` question #1.

### 3. Only if step 1 failed — re-encode with dense keyframes

Full decode + encode of 5.5 GB. Minutes on the LAN; do not attempt over the
VPN. Originals untouched.

```bash
mkdir -p "$VID/../video_all_densekey"
for f in "$VID"/*.mp4; do
    ffmpeg -v error -i "$f" -c:v libx264 -crf 20 -preset fast -g 25 \
        -c:a copy "$VID/../video_all_densekey/$(basename "$f")"
done
```

`-g 25` puts a keyframe every second, so any seek lands within a frame. Re-run
`test_seek` against one output before converting the intent into a decision.

---

## Getting a machine ready

The shell scripts here need `bash`, `ffmpeg` and `ffprobe`. **`ffprobe` ships
with `ffmpeg`** — one package gives you both, so there is nothing separate to
install. (`ffplay` is the one that is sometimes absent; nothing here uses it.)

```bash
sudo apt update && sudo apt install -y ffmpeg     # WSL / Ubuntu
ffprobe -version | head -1                        # confirm

git clone --recurse-submodules git@github.com:Qu1ncyRy4n/cclab_movie_project.git
cd cclab_movie_project
git submodule update --init          # cclab-matlab-tools; easy to forget
                                     # no SSH key on this machine? clone from
                                     # https://github.com/Qu1ncyRy4n/cclab_movie_project.git

bash probe_durations.sh --selftest
bash catalog_cuts.sh   --selftest
```

If a self-test fails, stop: that is an ffmpeg build problem, not a data
problem, and running against the real dataset will not tell you anything.

### Mounting the NAS from WSL

```bash
sudo mkdir -p /mnt/cclab
sudo mount -t drvfs '\\cns-nas.ucdavis.edu\cclab' /mnt/cclab
ls /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all | head
```

The mount does not survive a reboot. Re-run it, or add it to `/etc/fstab`.

### Rebuilding WSL from scratch

Only worth doing if the existing install is actually broken — for the catalog
job the requirement is just bash + ffmpeg + a NAS mount. From an admin
PowerShell:

```powershell
wsl --list --verbose             # what is installed now
wsl --unregister Ubuntu          # DESTROYS that distro's filesystem — export anything you want first
wsl --install -d Ubuntu
```

Then re-run the block at the top of this section. Nothing in this repo lives
inside WSL's filesystem, so a rebuild costs you the clone and the apt install,
nothing more.

**Or skip WSL entirely.** Nothing about the catalog job requires it — a Windows
ffmpeg build (`winget install Gyan.FFmpeg`) plus a PowerShell port of
`catalog_cuts.sh` would do the same work. The script is two ffmpeg invocations
in a loop. Ask if you want that version written.

In MATLAB:

```matlab
cd Code/exp01_transitions
buildSequence('selftest')            % de Bruijn balance + segment maths, no files
```

### Getting the videos locally

The videos are **not** in the repo and never will be (5.5 GB, gitignored). They
live on the NAS at
`\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all\`.

**You may not need a local copy.** Two different needs:
- *the catalog job* — no copy required. On the lab LAN, point `catalog_cuts.sh`
  straight at the NAS path and skip the 5.5 GB transfer entirely.
- *running the experiment* — yes, copy. A NAS hiccup mid-playback drops frames.

Convention for a local copy is **`C:\cclab_data\video_ebm_dataset\`** — off the
Desktop so OneDrive never tries to sync 5.5 GB, outside the repo, and laid out
exactly like the NAS share so nothing else has to change.

**On Windows (including a Remote Desktop session), use `robocopy`** — it is
native, resumable, and rsync writing to `/mnt/c` through WSL's drvfs layer is
slow enough to matter across 5.5 GB.

```powershell
# Windows, resumable, skips files already copied
robocopy "\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all" ^
         "C:\cclab_data\video_ebm_dataset\video_all" /E /Z /XO /R:3 /W:5
```

Only if you are working from a Linux/macOS shell and the destination is a real
Linux filesystem (not `/mnt/c`):

```bash
rsync -avP --partial \
  /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all/ \
  /mnt/c/cclab_data/video_ebm_dataset/video_all/
```

Verify, then point MATLAB at it:

```bash
ls /mnt/c/cclab_data/video_ebm_dataset/video_all/*.mp4 | wc -l    # expect 600
du -sh /mnt/c/cclab_data/video_ebm_dataset/video_all              # expect ~5.5G
```

```matlab
cclab.video_source = 'local';   % in CONFI_exp01_transitions.m
```

Over the VPN a cold read runs at ~430 KB/s, which is too slow to stream a movie
at all — off-site, `'local'` is the only workable setting.

If the NAS is not mounted in WSL:

```bash
sudo mkdir -p /mnt/cclab
sudo mount -t drvfs '\\cns-nas.ucdavis.edu\cclab' /mnt/cclab
```

---

## Map of what is where

| path | what it is |
|---|---|
| `Code/exp01_transitions/` | the experiment — see its own `README.md` for usage |
| `Code/exp01_transitions/test_seek.m` | the blocking check in step 1 |
| `Code/RUN_freeviewingTraining_movie.m` | the original pilot task, untouched, still runnable |
| `probe_durations.sh` | header-only duration probe (cheap; already run) |
| `catalog_cuts.sh` | keyframe + scene-cut catalog (expensive; step 2) |
| `video_ebm_dataset/durations.csv` | 600 measured durations |
| `video_ebm_dataset/MANIFEST.csv` | category membership per video |
| `exp_01_spec.md` | the spec, decisions log, and the open-questions list |

## Open questions live in the spec

`exp_01_spec.md`, section **Still open** — seven items, of which the two above
are the blocking ones. Put what you learn there rather than in a chat log.

## Loose ends worth knowing

- `video_clipped` (21 rows) and `video_boundary` (3 rows) in `MANIFEST.csv`
  describe files that exist nowhere — not on the NAS, not in the repo. Per
  `docs/snovik_readme.md`, they were abandoned attempts at boundary stimuli.
  Delete the rows unless the boundary idea is being revived.
- The README's TODO list still claims the TTL pulses are commented out. They
  are live in `Code/RUN_freeviewingTraining_movie.m`. The note is stale.
- Interleave mode fires ~8 TTL pulse pairs per trial where the pilot fired 1.
  Confirm with Brinda that the Neuropixel side tolerates that density before
  real collection.
- The PTB VBL sync failure on `lab_120` (DWM compositor) is inherited from the
  original task and still unresolved. It affects timing precision either way.
