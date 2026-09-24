# Cut structure across the full dataset

**2026-09-24.** Answers `exp_01_spec.md` open question #1 ("Cut structure —
the 6 s finding is n=1") and the belief flagged in `PICKUP.md` as "believed
but not yet established." This replaces the n=1 spot check with all 600
videos.

## What was run

```bash
bash catalog_cuts.sh --selftest   # verify detector: synthetic 2.0s cut found — OK
bash catalog_cuts.sh "$VID"       # full run, 600/600 videos, ~5 min on local disk
python3 video_ebm_dataset/analyze_cuts.py   # join + stats below
```

- `catalog_cuts.sh` → `video_ebm_dataset/cuts.csv`: per-video keyframe times
  and scene-cut times (`ffmpeg` scene-detection filter, threshold 0.15),
  committed alongside this doc.
- `video_ebm_dataset/analyze_cuts.py`: joins `cuts.csv` to `MANIFEST.csv` by
  filename stem (extension-agnostic, matching the convention already used by
  `pseudorandomization.m`), and to `durations.csv` for true per-video length
  (a few nature videos are short — see `PICKUP.md`). Re-run it any time
  `cuts.csv` changes; it prints the report below, nothing is cached.

Raw cut-count histogram, all 600 videos: 106 have 0 cuts, then roughly
bell-shaped from 1 to 9 (109, 117, 105, 75, 46, 33, 7, 1, 1).

## Per-category summary

| category | n | % zero-cut | mean cuts/video | median cuts/video | mean gap (s) | median gap (s) | gap std (s) | gap CV |
|---|---|---|---|---|---|---|---|---|
| nature | 300 | 25.3% | 1.74 | 2 | 10.81 | 7.86 | 8.44 | 0.78 |
| social_directed | 60 | 10.0% | 3.00 | 3 | 7.50 | 6.01 | 4.44 | 0.59 |
| social_undir | 240 | 10.0% | 3.12 | 3 | 7.28 | 6.01 | 4.94 | 0.68 |

"gap" = time between consecutive events (0 → first cut → ... → true video
end). CV = std/mean; low (<~0.3) means evenly spaced, high (>~0.6) means
irregular across the category.

## Is spacing even? Two different questions, two different answers

**Across a category (pooled), no** — CVs of 0.59–0.78 mean gap length varies
a lot from video to video. A single category-wide number like "6 s" is a
median, not a rule.

**Within a single video, often yes — strikingly so for `social_directed`.**
Restricting to videos with ≥3 cuts (≥2 interior gaps to compare, since a
single gap has a trivially-zero CV):

| category | n videos (≥3 cuts) | mean within-video gap CV |
|---|---|---|
| nature | 85 | 0.36 |
| social_directed | 36 | 0.00 |
| social_undir | 147 | 0.14 |

**The mean hides how different these categories are video-by-video.** Broken
down by regularity, not averaged:

| category | % of videos with CV < 0.10 (very regular) | % with CV > 0.30 (irregular) | CV range |
|---|---|---|---|
| nature | 8% | 49% | 0.02 – 1.08 |
| social_directed | **100%** | 0% | 0.00 – 0.02 |
| social_undir | 78% | 22% | 0.00 – 1.00 |

- `social_directed` isn't "regular on average" — it is regular in **every
  single one** of the 36 videos (max CV = 0.02). That is not a statistical
  tendency, it is a near-fixed interval across the entire category, which
  makes the camera-switch-artifact explanation below more plausible, not
  less — genuine editorial pacing does not come out this clean category-wide.
- `nature` is genuinely irregular for roughly **half** its videos, not just
  "less regular on average."
- `social_undir` is bimodal: most videos are quite regular, but a real
  minority (22%) are not.

**Caveat: some apparent irregularity is a detection artifact, not real
double-cuts.** E.g. `aggression06DVD` reports cuts at `0.033, 15.015,
15.048` — the last two are 33 ms apart, almost certainly one real cut
triggering the scene-score filter on two consecutive frames rather than two
distinct transitions. This inflates `n_cuts` and CV for a handful of videos
(several of the highest-CV "irregular" examples above are this artifact, not
genuine irregular pacing). Not yet corrected in `cuts.csv` — a de-duplication
pass (merge cuts within ~200ms) would clean this up if the exact `n_cuts`
count starts mattering for a decision.

`social_directed` videos with cuts are essentially metronomic. Examples,
straight from `cuts.csv`:

- `aggr_cam_directed09DVD`: cuts at 7.508, 15.015, 22.523 — gaps of 7.51,
  7.51, 7.51 s.
- `aggr_cam_directed13DVD`: cuts at 6.006, 12.012, 18.018, 23.991 — gaps of
  6.01, 6.01, 5.97 s.
- `aggr_cam_directed19DVD`: 6 cuts, all gaps 4.34 ± 0.01 s.

This regularity is too clean to be editorial pacing. `cam_directed` in the
filenames suggests a multi-camera rig with a fixed-interval camera switch —
i.e. these may be **camera-cut artifacts, not content/scene cuts** in the
sense the paradigm cares about. Worth a sanity check against the original
video source/production notes before leaning on this for stimulus design.

`nature` is the least regular (CV 0.36) — consistent with it being the most
heterogeneous, least controlled category (documentary-style footage, not a
directed shoot).

## The "~6 s cut" claim — does it hold at n=600?

Partially, and it doesn't hold the way `PICKUP.md` framed it:

- **Median gap is 6.01 s in *both* `social_undir` and `social_directed`** —
  not undirected-only. The original spot check (one file per category) is
  what created the "undirected cuts every 6 s, directed is continuous"
  picture; at full sample size, **directed is not continuous**. Only 10% of
  `social_directed` videos have zero cuts — the same rate as `social_undir`.
- Only ~19–25% of individual gaps actually fall in [5.5 s, 6.5 s] (undirected
  19%, directed 25%). The "6 s" figure is a central tendency, not a typical
  single gap — most gaps are somewhere else in a wide spread (std ≈ 4.5–5 s).
- `nature` is different again: fewer cuts overall (25% have none), and when
  cuts do occur they're spaced further apart on average (median 7.86 s) and
  less regularly (CV 0.78, the highest of the three).

## Bottom line for `exp_01_spec.md` open question #1

- The n=1 "directed videos are continuous" assumption is **false** at full
  sample size — update `exp_01_spec.md` and `PICKUP.md` accordingly (done,
  see below).
- If a single `clipDur` is still wanted, **6 s** remains a reasonable choice
  for the social categories (matches both medians), but it will cut mid-shot
  in roughly 80% of individual gap intervals, and `nature` behaves
  differently (~8 s median, far less regular) — a single dataset-wide
  `clipDur` is a simplification, not a natural constant.
- Given how regular `social_directed` gaps are, **per-video or per-category
  clip lengths** (e.g. driven directly by that video's own detected cuts)
  would track the actual structure much more closely than one global
  constant, if the pipeline can support it.
- The camera-switch-artifact possibility for `social_directed` cuts is worth
  resolving before treating those cut times as meaningful "transitions" —
  see the `aggr_cam_directed` note above.

## Reproducing / extending

```bash
python3 video_ebm_dataset/analyze_cuts.py
```

Pure Python (`pandas`/`numpy`), no state, safe to re-run after any
`cuts.csv` update. Needs the project's nix devShell (`nix develop`) or an
equivalent env with pandas — this system's bare `python3` was not on `PATH`.
