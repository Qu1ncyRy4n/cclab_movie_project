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

## Summary table

| option | new code | matches real footage | still "interleaved" per PI? |
|---|---|---|---|
| 1. tune the knob | none (config) | partially, one global guess | yes |
| 2. pairs + fixation | small (reuse `transitions` path) | n/a — no sub-clip alternation | questionable — confirm with PI |
| 3. stay arbitrary | none | no, explicitly punts on this | yes |
| 4. per-clip natural shots | moderate (`buildSequence.m` change) | yes, by construction | yes |

Recommendation from prior discussion: 1 or 2 as a stopgap if something needs
to run this week; 4 if there's time to do it properly. 3 is the no-op
fallback if 4 turns out not to be worth it.
