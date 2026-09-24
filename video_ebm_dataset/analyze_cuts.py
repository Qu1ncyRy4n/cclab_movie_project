#!/usr/bin/env python3
"""Join cuts.csv against MANIFEST.csv and characterize cut spacing per category.

Answers three questions from docs/PICKUP.md:
  1. Are cuts evenly spaced within a video, or irregular?
  2. Does the pattern differ by category (nature / social_directed / social_undir)?
  3. Does the "~6 s cut spacing in undirected social video" claim (n=1 spot check)
     hold up across the full dataset?

Usage: python3 analyze_cuts.py
Reads:  cuts.csv, MANIFEST.csv (both in this directory)
Writes: nothing — prints a report. Redirect to a file to save it.
"""

import pandas as pd
import numpy as np
from pathlib import Path

HERE = Path(__file__).parent
cuts = pd.read_csv(HERE / "cuts.csv", dtype=str).fillna("")
manifest = pd.read_csv(HERE / "MANIFEST.csv", dtype=str).fillna("0")
durations = pd.read_csv(HERE / "durations.csv", dtype=str)
durations["stem"] = durations["filename"].str.replace(r"\.\w+$", "", regex=True)
dur_lookup = durations.set_index("stem")["duration_s"].astype(float)

# MANIFEST filenames are .mpg/.mp4/mixed; cuts.csv is always .mp4. Match on
# basename without extension (per README: "MANIFEST matching is
# extension-agnostic (basename only)").
manifest["stem"] = manifest["filename"].str.replace(r"\.\w+$", "", regex=True)
cuts["stem"] = cuts["filename"].str.replace(r"\.\w+$", "", regex=True)

CATS = {
    "video_nature": "nature",
    "video_social_directed": "social_directed",
    "video_social_undir": "social_undir",
}


def category_of(row):
    for col, name in CATS.items():
        if row.get(col) == "1":
            return name
    return None


manifest["category"] = manifest.apply(category_of, axis=1)
# One row per stem (drop clipped/boundary variants and .mpg/.mp4 dupes — keep
# the row that actually carries a category flag).
cat_lookup = (
    manifest[manifest["category"].notna()]
    .drop_duplicates(subset="stem")
    .set_index("stem")["category"]
)

joined = cuts.copy()
joined["category"] = joined["stem"].map(cat_lookup)

matched = joined["category"].notna().sum()
total = len(joined)
print(f"Joined {matched}/{total} cuts.csv rows to a MANIFEST category "
      f"({total - matched} unmatched — likely non-video_all variants)\n")


def parse_times(s):
    return [float(x) for x in s.split(";") if x]


joined["cut_times"] = joined["scene_cuts"].apply(parse_times)
joined["n_cuts"] = joined["cut_times"].apply(len)
joined["duration_s"] = joined["stem"].map(dur_lookup).fillna(30.0)


def intervals(row):
    """Gaps between consecutive events, treating 0 and true video end as boundaries."""
    pts = [0.0] + sorted(row["cut_times"]) + [row["duration_s"]]
    return [b - a for a, b in zip(pts, pts[1:])]


joined["gaps"] = joined.apply(intervals, axis=1)

print("=" * 72)
print("PER-CATEGORY SUMMARY")
print("=" * 72)

rows = []
for cat in ["nature", "social_directed", "social_undir"]:
    sub = joined[joined["category"] == cat]
    n_videos = len(sub)
    n_zero = (sub["n_cuts"] == 0).sum()
    cut_counts = sub["n_cuts"]
    all_gaps = [g for gaps in sub["gaps"] for g in gaps]
    rows.append({
        "category": cat,
        "n_videos": n_videos,
        "pct_zero_cuts": 100 * n_zero / n_videos if n_videos else float("nan"),
        "mean_cuts_per_video": cut_counts.mean(),
        "median_cuts_per_video": cut_counts.median(),
        "mean_gap_s": np.mean(all_gaps) if all_gaps else float("nan"),
        "median_gap_s": np.median(all_gaps) if all_gaps else float("nan"),
        "std_gap_s": np.std(all_gaps) if all_gaps else float("nan"),
        "cv_gap": (np.std(all_gaps) / np.mean(all_gaps)) if all_gaps else float("nan"),
    })

summary = pd.DataFrame(rows)
print(summary.to_string(index=False, float_format=lambda x: f"{x:6.2f}"))
print()
print("cv_gap = coefficient of variation (std/mean) of inter-cut gaps.")
print("Low CV (<~0.3) => evenly spaced. High CV (>~0.6) => irregular/bursty.")
print()

print("=" * 72)
print("EVENNESS WITHIN INDIVIDUAL VIDEOS (videos with >= 3 cuts, so there are")
print(">= 2 interior gaps to compare — a single gap has a trivial CV of 0)")
print("=" * 72)
for cat in ["nature", "social_directed", "social_undir"]:
    sub = joined[(joined["category"] == cat) & (joined["n_cuts"] >= 3)]
    if len(sub) == 0:
        print(f"{cat}: no videos with >=3 cuts")
        continue
    cvs = []
    for gaps in sub["gaps"]:
        # exclude the boundary gaps (first/last, which run to 0 and video end,
        # not between two real cuts)
        interior = gaps[1:-1]
        if len(interior) >= 2 and np.mean(interior) > 0:
            cvs.append(np.std(interior) / np.mean(interior))
    print(f"{cat}: n={len(sub)} videos with >=3 cuts, "
          f"{len(cvs)} usable, mean within-video gap CV = {np.mean(cvs):.2f}"
          if cvs else
          f"{cat}: n={len(sub)}, insufficient interior gaps to assess")

print()
print("=" * 72)
print("THE ~6s CLAIM — full-dataset check")
print("=" * 72)
undirected = joined[joined["category"] == "social_undir"]
directed = joined[joined["category"] == "social_directed"]
und_gaps = [g for gaps in undirected["gaps"] for g in gaps]
dir_gaps = [g for gaps in directed["gaps"] for g in gaps]
print(f"social_undir     : {len(undirected)} videos, "
      f"{(undirected['n_cuts']==0).sum()} with zero cuts, "
      f"mean gap {np.mean(und_gaps):.2f}s, median {np.median(und_gaps):.2f}s")
print(f"social_directed  : {len(directed)} videos, "
      f"{(directed['n_cuts']==0).sum()} with zero cuts, "
      f"mean gap {np.mean(dir_gaps):.2f}s, median {np.median(dir_gaps):.2f}s"
      if dir_gaps else
      f"social_directed  : {len(directed)} videos, "
      f"{(directed['n_cuts']==0).sum()} with zero cuts, no cuts detected at all")

near_6s = lambda gaps: sum(1 for g in gaps if 5.5 <= g <= 6.5) / len(gaps) if gaps else 0
print(f"\nFraction of gaps landing in [5.5s, 6.5s]: "
      f"undirected {near_6s(und_gaps):.0%}, directed {near_6s(dir_gaps):.0%}")
print("(i.e. the ~6s claim describes the MEDIAN, not most individual gaps — "
      "spacing varies a lot per video, per the CV figures above.)")
