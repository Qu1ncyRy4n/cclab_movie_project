# Interleave redesign — options

**2026-09-24.** Follow-up to `docs/cuts_analysis.md`: the current
`interleave` mode alternates two clips every `interleaveSegDur = 2.5 s`
(`CONFI_exp01_transitions.m`), but the dataset's real cut rhythm is ~6–8 s
median, category-dependent (see that doc). 2.5 s segments land mid-shot
almost every time. This doc lays out options, not a decision — pick one (or
ask the PI) before anyone writes code against it.

Context this assumes: PI wants clips "alternating and interleaved."
`buildSequence.m`'s `buildInterleave()` currently hardcodes exactly 2 clips
per trial, A-B-A-B, drawn from the 9 ordered category pairs (including
same-category pairs), balanced the same way `transitions` mode's de Bruijn
sequence balances category order.

---

## Cut stats, at a glance

Full numbers, method, and caveats: `docs/cuts_analysis.md`. Condensed here so
the options below don't need a second tab open.

| category | n | % zero-cut | mean cuts/video | median gap (s) | gap CV (pooled) | within-video gap CV (≥3 cuts) |
|---|---|---|---|---|---|---|
| nature | 300 | 25.3% | 1.74 | 7.86 | 0.78 | 0.36 |
| social_directed | 60 | 10.0% | 3.00 | 6.01 | 0.59 | **0.00** (near-metronomic) |
| social_undir | 240 | 10.0% | 3.12 | 6.01 | 0.68 | 0.14 |

CV = std/mean of inter-cut gaps. Low = evenly spaced, high = irregular.
"Pooled" is across all videos in the category; "within-video" restricts to
gaps inside one video (≥3 cuts, so there's something to compare).

Cut-count histogram, all 600 videos (`#` = 10 videos, rounded):

```
0 cuts  [106] ##########
1 cut   [109] ###########
2 cuts  [117] ############
3 cuts  [105] ##########
4 cuts  [ 75] ########
5 cuts  [ 46] #####
6 cuts  [ 33] ###
7 cuts  [  7]
8 cuts  [  1]
9 cuts  [  1]
```

Headline takeaways that motivate the options below:
- **`social_directed` is not continuous** (only 10% zero-cut, same as
  `social_undir`) — the n=1 belief that motivated the original design was
  wrong.
- **Median gap is 6.01s in both social categories**, but only ~19–25% of
  individual gaps actually fall near 6s — it's a central tendency, not a
  typical single gap (std ≈ 4.5–5s).
- **`social_directed` gaps are near-metronomic within a video** when cuts
  occur (mean within-video CV ≈ 0.00) — possibly a multi-camera switch
  artifact rather than a content cut.
- **`nature` is the outlier**: fewer cuts, longer and less regular gaps than
  either social category.

---

## Baseline — what's running today

```
CONFI: interleaveSegDur = 2.5s, interleaveClipTotal = 10s  →  8 segments/trial

  0    2.5   5.0   7.5   10.0  12.5  15.0  17.5  20.0   (s)
  |--A--|--B--|--A--|--B--|--A--|--B--|--A--|--B--|
     a1    b1    a2    b2    a3    b3    a4    b4

  a1..a4 = consecutive 2.5s slices of clip A (seek advances each time)
  b1..b4 = consecutive 2.5s slices of clip B
  fixation dot at every | boundary if t_fix_between > 0 (default 0.5s)

Segment length (2.5s) << median real cut gap (6-7s): almost every
segment boundary falls MID-SHOT, not on a natural cut.
```

---

## Option 1 — tune the existing knob

Same mechanism, just a bigger `interleaveSegDur`. Zero new logic.

```
CONFI: interleaveSegDur = 7s, interleaveClipTotal = 28s  →  8 segments/trial

  0      7      14     21     28        (s)
  |--A---|--B---|--A---|--B---|
     a1     b1     a2     b2

Trial is now ~28s of screen time per pair instead of 20s.
```

**Compatibility:** highest — one config value.
**Weakness:** one global number can't match nature's ragged ~7.9s median AND
social's tighter ~6-7s median AND social_directed's near-metronomic 4-6s
clips all at once. Still frequently mid-shot for any individual clip.

---

## Option 2 — pairs with fixation (collapse to `transitions`-like structure)

Two *whole* clips shown back to back, not sub-clip alternation. This is
close to `transitions` mode with `clipsPerTrial = 2`, or equivalently
`interleaveSegDur = interleaveClipTotal` (one segment = one whole clip).

```
  Trial N:
  |========= clip A (full, ~10-30s) =========|--fix--|========= clip B =========|--fix--|
                                        (t_fix_between)                    (into Reward/ITI)

  Trial N+1:
  |========= clip C =========|--fix--|========= clip D =========|--fix--|
```

**Compatibility:** high — nearly the original pilot task's shape
(one clip, fixation-gated boundary, reward), reusing far more of
`RUN_exp01_transitions.m`'s existing `transitions` path than `interleave`'s.
**Weakness:** this is *block* alternation (AB across trials), not the rapid
within-trial A-B-A-B interleaving the PI described. Confirm with the PI
whether this still counts as "interleaved" before treating it as the fix —
it changes the definition, not just the timing.

---

## Option 3 — stop trying to match content; keep segments arbitrary

Functionally the baseline (or Option 1) accepted as-is: pick a segment
length for experimental reasons (attention span, trial duration budget,
whatever), don't try to align it to real cuts at all.

```
  Same diagram as Baseline or Option 1 — no new diagram, no new code.
  Difference is only in how it's JUSTIFIED: not "matches the footage's
  natural rhythm," just "a duration we picked."
```

**Compatibility:** total — this is doing nothing.
**Weakness:** discards the point of `cuts.csv`/`cuts_analysis.md`. Fallback
if the fancier options prove not worth the effort, not a real redesign.

---

## Option 4 — segment length follows each clip's own cuts

Instead of one global `interleaveSegDur`, each drawn clip's segments are
*its own* detected shots, pulled straight from `cuts.csv`. Same A-B-A-B
alternation and de Bruijn category-pair balance as today — only the source
of each segment's duration changes, from "config constant" to "this video's
next real cut."

```
  Clip A = aggr_cam_directed19DVD (social_directed, near-metronomic):
    cuts at   0    4.34  8.68  13.01 17.35 21.69 25.86
    shots:    |-4.34-|-4.34-|-4.33-|-4.34-|-4.34-|-4.17-|

  Clip B = aggression01DVD (social_undir, ~6s rhythm):
    cuts at   0     6.01        12.01       18.02       24.02
    shots:    |--6.01--|--6.01--|--6.00--|--6.00--|

  Interleaved trial (alternate, each segment = that clip's OWN next shot):

  0      4.34        10.34       14.68        20.68       25.02     (s)
  |--A1--|----B1------|----A2-----|-----B2-----|----A3----|
   4.34s     6.01s        4.34s       6.01s        4.34s
  (clip A's shot 1)  (clip B's shot 1)  (A's shot 2) ...

  Boundaries now land where the FOOTAGE actually cuts, for whichever
  clip is currently "on screen" — not on an arbitrary global clock.
```

**Compatibility:** medium — reuses the alternation/balance skeleton of
`buildInterleave()`, but needs: (a) a per-clip cut-boundary lookup from
`cuts.csv` instead of a fixed `interleaveSegDur`, (b) a fallback duration for
clips with 0 detected cuts (106/600 videos), (c) a decision on trial-length
variability, since total trial duration now depends on which clips got
drawn instead of being a fixed constant.
**Strength:** the only option that uses what `cuts_analysis.md` actually
found instead of averaging over it, and avoids the population-mismatch
problem in cut-count-matching (4 nature videos at n=6 vs. hundreds at n=2) by
matching *rhythm structurally*, per clip, rather than picking specific clips
to have equal cut counts.

---

## Option 5 — trial length = min(clip A usable, clip B usable)

Not a segmentation rule like 1/2/4 — this is a **stopping rule**, and
composes with any of them. Instead of a fixed `interleaveClipTotal` (or
letting Option 4 truncate to an arbitrary shot count), cap the whole trial
at whichever of the two drawn clips runs out of usable material first, and
stop there rather than looping or overrunning.

```
  Trial draws: clip A (aggression01DVD, full 30.0s available from its
  random start offset) paired with clip B (00364DVD, a short nature video —
  only 7.0s long total, per durations.csv).

  trial length = min(30.0, 7.0) = 7.0s

  0                                    7.0s   (s)
  |--A1--|--B1--|--A2--|-- stop, B exhausted --
  (segment cutting rule — fixed segDur, or per-clip natural shots — is
   whatever Option 1/2/4 you're already using; this only decides WHEN to
   stop instead of hitting a config constant or an arbitrary shot cap.)
```

**Compatibility:** small, targeted change — `drawClip()` in `buildSequence.m`
already computes `maxStart = durationS - needS` per clip; this just means
comparing the two drawn clips' *actual remaining runway*
(`durationS - startS`) and using the smaller one as the trial's segment
budget, instead of assuming both clips have `interleaveClipTotal` seconds to
spare.
**How much this matters in practice:** limited, given the dataset — 592/600
videos are ~30.0s already (`durations.csv`), so for most drawn pairs
`min(A, B) ≈ 30s` regardless, same as today. It only bites for the 8 short
files (7.0s–29.5s, all `nature`, e.g. `00364DVD.mp4` at 7.0s) — but for
those it fixes a real bug-in-waiting: without this, a fixed
`interleaveClipTotal` longer than a short clip's remaining material would
either error out or (worse) silently request time past the video's end.
**Recommendation:** cheap and low-risk enough to adopt regardless of which
of 1/2/4 gets picked for the segmentation question — it's a correctness fix
for the short-nature-video edge case more than a design tradeoff.

---

## Summary table

| option | new code | matches real footage | still "interleaved" per PI? |
|---|---|---|---|
| 1. tune the knob | none (config) | partially, one global guess | yes |
| 2. pairs + fixation | small (reuse `transitions` path) | n/a — no sub-clip alternation | questionable — confirm with PI |
| 3. stay arbitrary | none | no, explicitly punts on this | yes |
| 4. per-clip natural shots | moderate (`buildSequence.m` change) | yes, by construction | yes |
| 5. min(clip A, clip B) trial length | small, targeted | n/a — stopping rule, composes with 1/2/4 | yes |

Recommendation from prior discussion: 1 or 2 as a stopgap if something needs
to run this week; 4 if there's time to do it properly. 3 is the no-op
fallback if 4 turns out not to be worth it. 5 is close to free and worth
doing regardless of which segmentation option ships, since it also closes a
real edge-case bug against the 8 short `nature` videos.

---

## Design-space generalization

**2026-09-24 (later).** Options 1–5 above, plus the five shot-pool
"presentation schemes" (P1–P5, built only in
`docs/demos/interleave_options_demo.html`'s later tabs — not written up as
prose here to avoid duplicating the demo), all turn out to be points on a
2-axis grid, not an unrelated list.

**Rows — unit type** (how the video gets cut):
- **Full video** — uncut, whole ~30s parent played straight through.
- **Arbitrary slice** — precut to a fixed duration by a config constant,
  ignores real content boundaries.
- **Natural shot** — precut at the video's own real scene-cut boundaries
  (`cuts.csv`).

**Columns — arrangement** (how units from different categories sit in time):
- **Separate** — one unit per trial, category order pseudo-randomized
  *across* trials, not within one.
- **Blocked run** — several same-category units back to back within a
  trial, then switch category.
- **Interleaved, fixed pair** — 2 specific clips alternate for the whole
  trial (today's `buildInterleave()`).
- **Interleaved, free pool** — each segment drawn independently from the
  category pool; not locked to 2 parents.

| | Separate | Blocked run | Interleaved, fixed pair | Interleaved, free pool |
|---|---|---|---|---|
| **Full video** | = the *original pilot task* (`RUN_freeviewingTraining_movie.m`) — already built, already piloted, not part of `exp_01` | not meaningful — just consecutive trials in the original design | **structurally impossible** — can't rapid-alternate without cutting the video | **structurally impossible**, same reason |
| **Arbitrary slice** | not built, low value — a random-length slice with no principled start/end, and no partner to justify calling it "interleaved" | not built — easy extension of P4 with fixed-length slices | **= Baseline / Option 1** | not built — easy extension of Baseline/Option 1, drawing from the pool instead of 2 fixed clips |
| **Natural shot** | **= P2** — ⚠️ content-identical to Full-video×Separate; reassembling one clip's own shots in their original order doesn't change what's shown, only that it's now addressable as named units. Real content differences only appear once you reorder, interleave, or mix parents. | **= P4** | **= Option 4** | **= P1** (free alternation), **P3** (duration-matched), **P5** (3-way chain) |

Two more things vary independently of both axes — they're modifiers on a
cell, not cells of their own:
- **Trial-length rule**: fixed constant vs. Option 5's `min(clip A usable,
  clip B usable)`. Applies to any cell with more than one unit per trial.
- **Matching criterion** (interleaved cells only): none / duration-matched
  (P3) / cut-count-matched (the original idea from this discussion —
  dropped, see the population-mismatch note in `docs/cuts_analysis.md`:
  only 4 `nature` videos exist at a 6-cut count vs. 23 `social_undir`).

**What the grid makes obvious that the flat option list didn't:**
- "PI wants interleaved" already rules out the entire **Full video** row —
  both interleaved cells there are not just unbuilt, they're impossible.
  The original pilot task (Full video × Separate) is a different thing
  entirely, not a fallback interleave option.
- **Natural shot** is the only row with a real, meaningful answer in every
  column — the strongest structural argument yet for it over arbitrary
  slicing, independent of the earlier rhythm/regularity findings.
- **P2 isn't really a new design** — it's a control condition proving that
  splitting a video into shots, by itself, is a no-op unless something is
  also done with the reordering.
- The three unbuilt **Arbitrary slice** cells are trivial to fill if ever
  wanted, but there's no reason to prefer them over the equivalent
  **Natural shot** cell in the same column — they're strictly worse by the
  same logic that motivated this whole redesign.
