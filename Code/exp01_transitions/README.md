# exp_01 — transitions / interleave

Free viewing across video transitions. A trial is a playlist of **segments**;
a segment is a time window of a parent video, seeked to in place. Nothing is
split on disk.

```
Code/exp01_transitions/
├── RUN_exp01_transitions.m     ← run this
├── CONFI_exp01_transitions.m   ← all params (set computer_name + video_source)
├── buildSequence.m             ← playlist builder (both modes)
├── test_seek.m                 ← RUN THIS FIRST ON A NEW MACHINE (see below)
└── testdata/seek_test.mp4      ← 30 s test pattern, sparse GOP, burned-in seconds
```

## Run it

```matlab
cd Code/exp01_transitions
RUN_exp01_transitions
```

Enter a subID (≤8 chars) at the dialog — that becomes the EDF filename.
Keys during a run: `ESC` quit, `PageUp` pause, `PageDown` resume.

Output lands in `Output_exp01_transitions/<subID>_<timestamp>/` relative to
whatever directory MATLAB was in. **One row per segment**, not per trial.

## Before anything else, on a new machine

```matlab
test_seek            % ~10 s, no NAS needed, no monkey
```

Reads the burned-in second counter back out of a seeked video. If requesting
13.7 s shows you `13`, seeking is accurate and the design holds. If it shows
`8`, PTB is snapping to keyframes and **interleave mode is silently wrong** —
every segment would play the wrong footage. Remedies are listed at the top of
`test_seek.m`. Do not collect data before this passes.

```matlab
buildSequence('selftest')   % checks de Bruijn balance + segment maths, no files
```

## Config you will actually touch

`CONFI_exp01_transitions.m`:

| param | what it does |
|---|---|
| `computer_name` | picks the machine block. Add a `case` for a new machine. |
| `video_source` | `'nas'` reads the share directly; `'local'` reads a local copy. Over the VPN the NAS runs ~430 KB/s — too slow to stream. Use `'local'` off-site. |
| `mode` | `'transitions'` (clips back to back, de Bruijn order) or `'interleave'` (two clips alternating). |
| `clipDur` | segment length in transitions mode. |
| `clipsPerTrial` | clips between rewards. 3 ≈ 30 s + fixations. |
| `interleaveSegDur` / `interleaveClipTotal` | 2.5 / 10 → A B A B A B A B, 8 segments, 7 cuts. |
| `t_fix_between` | `>0` = fixation dot at every cut (default 0.5 s); `0` or `-1` = continuous stream. |
| `nCycles` | passes through the condition set. |
| `pilot` | restrict to `pilot_ready=1` rows in MANIFEST. |

## The two modes

Same playlist structure, different segment boundaries:

```
transitions:  [A 0-10]              [B 0-10]              [C 0-10]        → 1 cut per pair
interleave:   [A 0-2.5] [B 0-2.5] [A 2.5-5] [B 2.5-5] ...                 → 7 cuts per trial
```

`transitions` orders categories by an order-2 de Bruijn sequence, so all nine
ordered pairs (`N->N` … `U->U`) occur equally often and no clip type is
systematically preceded by another. `interleave` equalizes exposure to both
clips inside one trial, making the comparison within-trial.

In `transitions` mode the de Bruijn cycle runs across trial boundaries; the
first segment of each trial is tagged `trial_start` and should be dropped from
transition analyses.

## Results columns

`TrialNum`, `SegIndex`, `Mode`, `MovieFile`, `MovieCategory`, `SourceFile`,
`ClipStart_s`, `SegDur_s`, `PrevCategory`, `TransitionType`, `SegRect`,
`SegOn`, `SegOff`, `TrialSuccess`, `RewardSize`, `AbortPhase`.

`SegOn`/`SegOff` are ms relative to trial start, matching the original task.
"Same vs different source" is `SourceFile` equality between consecutive rows.

## EyeLink / TTL

Per segment: `Eyelink('Message', 'SegOn_<trial>_<seg>')` + `cclabPulse('A')` at
onset, `SegOff_...` + `cclabPulse('B')` at offset. Trial-level messages
(`TrialStart_`, `FixInFP_`, `Reward_`) are unchanged from the original task.

⚠ Interleave produces ~8 pulse pairs per trial where the pilot task produced 1.
Confirm the Neuropixel side can take that pulse density before real collection.

## Known ceilings

- Seek accuracy — see `test_seek.m` above. Unresolved until someone runs it.
- Clip lengths assume the parents are 30 s. `durations.csv` confirms 592/600;
  `buildSequence` drops anything too short for the requested clip.
- `clipDur = 10` is a guess. Cut detection on one undirected video found
  content changes every 6 s. See `cuts.csv` once it exists.
- PTB VBL sync failure on `lab_120` is inherited from the original task and
  still unresolved.
