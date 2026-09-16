
This task will be a free-viewing paradigm using video data.

Each video in the dataset is 30 seconds long, but all social videos appear to be 3 x 10 sec videos. These videos will have to be split into 10 second videos.
Possibly the same for others.
We must first confirm that these videos are of the same length. Otherwise, something like 6 sec per video.

Multiple conditions: but different combs of content: within category, outside of category, etc.

Nature, Nature
Social, Nature (and rev)
- Social = directed,
- Social = undirected
Social, Social (and rev )
- Social = same
- Social = different

Maybe 3 videos per?
Also, maybe marked on the transitions: Although we will likely just do a continuous video set without fixations between, might make sense to have it blocked. Maybe fixation separation would make it easier. 
The clustering of video seems a little challenging, maybe easier to analyise on the basis of transitions between videos instead of block conditions? 

Should there or should there not be any sort of fixation? Should there be any sort of reward? or block? or rest period?

All eye tracking and neural data programmed into previous tasks should be included as well. 

video data set split:

Nature videos and other continuous / full 30 sec video: `original_filename_0-9` `original_fname_10-19`, etc

Social stim / fragmented videos: `original_filename_a` `original_filename_b`, etc.

The sources of the split video should be tracked in the ledger.

Will need a repo wide convention to keep code clean so we can have multiple experiments / codebases here, while using one repo, should all be nice and portable.
Must run in matlab for now (not enough time for large python framework refactor)
Must resemble exisiting code fairly well.
Going to have to go in with neural data a little blind, and troubleshoot from however the data comes back. 

Possilbe refactor into python soon or somewhat later.



---

## Decisions log (2026-09-15)

### Video durations — BLOCKING, now testable
`probe_durations.sh` added at repo root. Run it where the videos live (WSL box
or rig), commit `video_ebm_dataset/durations.csv`. That CSV is the evidence for
every number below. `bash probe_durations.sh --selftest` verifies the ffprobe
parsing without touching the dataset.

Pool math **if** the 3 x 10 s assumption holds:

| category | parents | 10 s clips |
|---|---|---|
| nature          | 300 | 900 |
| social_directed |  60 | 180 |
| social_undir    | 240 | 720 |

180 directed clips is the binding constraint, and it is plenty.

### Transitions vs blocks — do not choose, generate one sequence that serves both

Alphabet is 3 symbols: `N` nature, `D` social-directed, `U` social-undirected.
Every condition the spec lists is an ordered pair over those 3:

```
N->N   N->D   N->U
D->N   D->D   D->U
U->N   U->D   U->U
```

All 9 ordered pairs, each exactly once, in a cyclic sequence of 9 clips — an
order-2 de Bruijn sequence. At 10 s/clip that is a 90 s cycle. Several cycles
per session, reshuffled within category each cycle.

Why transitions over blocks:
- **Efficiency.** n clips give n-1 transitions; every clip is both an offset and
  an onset. A blocked design spends the same clips on far fewer condition
  samples.
- **Time-locking.** The cut is a discrete event. Gaze (first saccade latency,
  target of first fixation post-cut) and neural (PSTH around the cut) both want
  an event, not an epoch average. Matches how the Neuropixel data will be
  analysed anyway.
- **Drift.** Block designs confound condition with slow arousal/satiation drift
  across the block. Interleaved transitions distribute that across conditions.

Why the blocked analysis is not lost: a de Bruijn sequence contains runs of the
same category by construction (`D->D`, `N->N` etc.), so category-block effects
are recoverable post hoc by binning on run length. One generator, both analyses.
Do not build a separate blocked mode.

Open risk: **carryover.** The response after a cut is driven by clip B's own
content as well as by the A->B type. The de Bruijn constraint handles first-order
balance (each B preceded equally often by each A). Do not hand-order sequences.

"Social same vs different" (spec) is a *finer* cut than D/U: it means whether
consecutive clips share a parent video. That falls out of the `source_file`
column post hoc — another reason the split provenance goes in MANIFEST columns,
not in the filename.

### Fixation between clips — yes, with a disable knob
`cclab.durations.t_fix_between` in the exp_01 CONFI:
- `> 0` — fixation dot for that many seconds at each transition. Re-zeroes gaze
  at the cut, so the first post-cut saccade is not confounded by wherever the eye
  happened to land at the end of clip A. This is the default.
- `<= 0` (use `0` or `-1`) — no fixation, fully continuous stream.

The knob exists because the trade is real and untested: the fixation cleans up
the saccade measure but breaks the continuity that makes the cut a naturalistic
event. Pilot both before committing.

### Clip naming — use the convention already in the repo
Repo already ships 21 clips as `NAME_1.mp4`, `NAME_2.mp4` (`video_clipped` in
MANIFEST). Keep that. Do **not** adopt `_0-9`/`_a` from the draft above — the
timing information goes in MANIFEST columns, not the filename:

```
filename, ..., source_file, clip_start_s, clip_end_s, clip_index
```

Filenames as a database is what breaks in six months.

### Repo layout for multiple experiments
`Code/exp01_transitions/` with its own `RUN_`/`CONFI_` pair; shared helpers go to
the `cclab-matlab-tools` submodule. `CONFI.matlab_path` already does `addpath` —
one `genpath` change covers the subfolder. Existing flat task stays where it is.

---

## Build notes (2026-09-16)

### Durations — measured, no longer an assumption
`video_ebm_dataset/durations.csv`, 600 files probed off the NAS.
- **592/600 are 30.0 s.** All 300 social videos (60 directed + 240 undirected)
  are 30 s with near-zero spread.
- 8 nature videos are short: 7.0, 8.0, 10.0, 12.6, 16.2, 16.3, 23.3, 29.5 s.
  `buildSequence.m` drops any video too short for the requested clip, so these
  exclude themselves.

### The 3 x 10 s claim is wrong — it looks like 5 x 6 s, and only for undirected
Scene-cut detection on `aggression01DVD.mp4` puts cuts at **6.006, 12.012,
18.018, 24.024 s** (scores 0.26-0.37 against a 0.09 noise floor) — five 6 s
segments, not three 10 s ones. `neutral_cam_directed01DVD.mp4` has no cut
anywhere above 0.05: continuous 30 s.

**This is n=1 per category.** Re-run across ~4 files per category before
trusting it. If it holds, `cclab.clipDur` should be 6 for undirected material
and the directed clips are free-cut anywhere.

### Interleave is not a separate paradigm
Plain transitions and interleaving are the same playlist with different segment
boundaries, so there is one playback engine:
- `transitions`: `[(A,0,10), (B,0,10), ...]` — 1 cut per pair
- `interleave` : `[(A,0,2.5), (B,0,2.5), (A,2.5,2.5), (B,2.5,2.5), ...]` —
  8 segments, 7 cuts, 10 s of each clip

Interleaving equalizes total exposure to both clips inside one trial, so a
difference between them cannot be attributed to one clip happening to land at a
better moment in the session — it converts a between-trial comparison into a
within-trial one, and buys 7 transition events per trial instead of 1.
Successive segments of the same clip advance through it (0-2.5, 2.5-5.0, ...)
so no footage is seen twice.

### Clips are seeked in place — nothing is split on disk
`Screen('SetMovieTimeIndex')` before `PlayMovie`. No new files, no NAS write
traffic, no cluster job, and MANIFEST needs no new rows. Segment provenance
lives in the Results table (`SourceFile`, `ClipStart_s`, `SegDur_s`).

**Unverified ceiling:** PTB's seek may snap to the nearest keyframe. `encode_mp4.sh`
used libx264 defaults, so the GOP may be ~10 s — which would make a 6 s seek land
at 0 or 10. Decisive check, needs the NAS mounted:

```
ffprobe -v error -select_streams v:0 -skip_frame nokey \
        -show_entries frame=pts_time -of csv=p=0 aggression01DVD.mp4
```

Sub-second spacing → done. ~10 s spacing → re-encode with `-g 25` (same cost as
splitting, so split instead) or snap segment boundaries to keyframes.

### video_clipped / video_boundary
Per `docs/snovik_readme.md:37`, both were Novik's attempts at boundary stimuli
made with online clipping tools. Never wired into any paradigm, not present on
the NAS (which has only `video_all/`). The 21 `video_clipped` rows and 3
`video_boundary` rows in MANIFEST describe files that exist nowhere. Delete the
rows unless the boundary idea is being kept.

## Still open

1. **Cut structure** — the 6 s finding is n=1. Sample ~4 per category. Sets `clipDur`.
2. **Keyframe spacing** — decides seek-in-place vs. actually splitting. One command.
3. **Which mode ships** — `transitions` or `interleave`. Both run; pilot both.
4. **Fixation between segments** — `t_fix_between = 0.5` default vs `0` continuous. Pilot both.
5. **Trial length** — `clipsPerTrial = 3` (30 s + fixations) is a guess about how
   long a monkey will work without reward. Tune on the rig.
6. **TTL letters** — segment onset reuses `cclabPulse('A')`, offset `'B'`, same as
   the existing task. With ~8 segments per trial that is a much denser pulse
   train than the pilot ever produced. Confirm with Brinda that the Neuropixel
   side can take it before real collection.
7. **PTB VBL sync failure on lab_120** — inherited, unresolved, blocks real
   timing on the rig either way.
