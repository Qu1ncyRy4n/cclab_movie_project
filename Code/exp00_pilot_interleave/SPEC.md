# exp_00 Pilot Specification

Status: active rig pilot. This document describes the behavior of
`RUN_exp00_pilot.m` with `CONFI_exp00_pilot.m`; it is the reference to update
when a design decision changes.

## Purpose

Exercise the complete collection chain with a deliberately small,
naturalistic free-viewing task: display interleaved nature and social videos,
collect gaze and neural-system TTL markers, and issue an unconditional reward
after a completed trial. It is not a balanced confirmatory experiment.

## Current Design

Each trial selects two distinct videos uniformly at random from the eight-item
pool. The videos may be from the same or different categories. They are played
in this order:

```text
fixation hold -> A1 -> B1 -> A2 -> B2 -> A3 -> B3 -> reward -> ITI
```

The task runs for up to 20 trials. `ESC` then `ESC` again within three seconds
ends the whole session. Up Arrow requests a safe pause: during fixation it
pauses immediately; during a trial it pauses after that trial saves. Down Arrow
resumes. `F` during movie playback aborts the current trial, saves it as
`ForcedPause`, then pauses before the next unused trial number.

### Trial Timeline

| Phase | Current behavior | Duration |
|---|---|---:|
| Fixation acquisition | Central dot waits indefinitely for gaze in the acceptance window. Loss during the hold restarts acquisition. | Variable |
| Fixation hold | Gaze must remain in the window after acquisition. | 0.85 s |
| Interleave | Six segments: three from A and three from B. No fixation between segments. | 12 s nominal |
| Reward | Green reward image and juice delivery after a completed interleave. | 1 s image; 400 ms command by default, configurable 1-2000 ms |
| ITI | Grey blank screen. | 2 s |

`segDur = 2 s`, `perClipSeconds = 6 s`, and `segsPerClip = 3`. The six
segments should therefore yield six onset and six offset event markers per
completed trial.

With neural I/O enabled, segment onset and offset use TTL lines `A` and `B`.
Safe/forced pause and resume use `C` and `D`, respectively. All markers use
the configured 50 ms width.

## Stimuli

The pool is `video_ebm_dataset/pilot_pool.csv`. Playback starts at each row's
verified natural-shot offset, not necessarily at video time zero.

| Category | File | Start (s) | Verified shot (s) | Pilot ready |
|---|---|---:|---:|---:|
| nature | `00181DVD.mp4` | 0.000 | 14.55 | yes |
| nature | `00182DVD.mp4` | 0.000 | 30.10 | yes |
| nature | `00189DVD.mp4` | 4.137 | 14.11 | yes |
| nature | `00191DVD.mp4` | 0.000 | 29.93 | no |
| social_undir | `foraging02DVD.mp4` | 0.000 | 14.98 | yes |
| social_undir | `foraging03DVD.mp4` | 0.000 | 10.01 | yes |
| social_undir | `foraging04DVD.mp4` | 0.000 | 30.02 | no |
| social_undir | `foraging06DVD.mp4` | 0.000 | 10.01 | no |

`pilot_ready = no` means the file passed programmatic validation but has not
received full manual lab QC. There is no exposure balancing, transition
balancing, or repeat avoidance in this pilot. `TimesShownBeforeA` and
`TimesShownBeforeB` preserve the exposure history for later analysis.

## Gaze and Reward

On `lab_120` and `lab_121`, EyeLink and neural I/O default to enabled. The
launcher can independently set each to `auto`, `on`, or `off`; when EyeLink is
off, the mouse supplies gaze for task-flow testing. The fixation point is black,
centered, and has radius 0.25 degrees. The acceptance window is 3 degrees. The reward is
unconditional once the interleave completes: base duration 400 ms by default,
with random doubling currently disabled.

Mouse-as-gaze is appropriate for software checks only. It validates task flow
and messages, not animal eye behavior or calibration.

## Event and TTL Contract

EyeLink messages are the descriptive event record. The neural recording system
uses TTL for clock alignment.

| Event | EyeLink message | TTL output | Current line | Width |
|---|---|---|---|---:|
| Segment onset | `SegOn_<trial>_<segment>_<A|B>` | A | `Dev2/port0/line4` | 50 ms |
| Segment offset | `SegOff_<trial>_<segment>_<A|B>` | B | `Dev2/port0/line3` | 50 ms |
| Pause | event log `ControlMarker` | C | `Dev2/port0/line5` | 50 ms |
| Resume | event log `ControlMarker` | D | `Dev2/port0/line7` | 50 ms |
| Reward | `Reward_<trial>` | reward analog output | `Dev2/ao0` | configured command |

The TTL lines intentionally identify onset versus offset, not trial or video
identity. Recover trial, segment, and A/B identity by joining neural TTL times
to EyeLink messages and the MATLAB Results table. Do not add serial pulse-count
encoding unless the recording hardware cannot preserve A/B as separate lines.

## Outputs

Each archived run contains:

| Artifact | Contents |
|---|---|
| `experiment/Output_exp00_pilot/<subject>_<time>/*.mat` | `Results` trial table and saved configuration |
| `experiment/Output_exp00_pilot/<subject>_<time>/*.edf` | EyeLink samples, built-in events, and task messages |
| `logs/runner_transcript.txt` | MATLAB/PTB/rig transcript |
| `run_metadata.json` | rig profile, paths, screen, and archive metadata |

`Results` has one row per started trial. Key fields are video A/B and category,
`SameCategory`, fixation/interleave/reward times, `AbortPhase`, `TrialSuccess`,
`RewardSize`, and pre-trial exposure counts. An interrupted interleave is
retained with `TrialSuccess = 0`; it may still contain useful partial EDF data.
Each row now also records `Participant` and `Experimenter`; allowed participant
labels are `Vennie`, `Isaac`, and `DEV-00`.

## Parameters To Decide With PI

| Parameter | Current value | Decision needed |
|---|---:|---|
| Segment duration | 2 s | Compare 2 versus 3 s for natural viewing and event density. |
| Per-video exposure per trial | 6 s | Decide whether this is enough to observe free viewing before reward. |
| Trial count | 20 | Tune to actual animal engagement and session constraints. |
| ITI | 2 s | Compare 2 versus 3 s if reward/attention recovery needs more time. |
| Pair selection | Uniform random | Decide whether category-pair or exposure balancing is scientifically required. |
| Pool QC | 8 files, 3 not fully QCed | Confirm whether to retain or replace the unvetted files. |
| TTL width | 50 ms | Confirm against neural recording-system input requirements. |
| Fixation dot radius | 0.25 degrees | Tune visibility without changing the 3-degree acceptance window. |
| Between-segment fixation | None | Keep continuous viewing or add resets for cleaner post-cut gaze measures. |

The future 10-epoch design is kept separately in `DESIGN_exp00_session.m` and
checked by `CHECK_exp00_feasibility.m`. These files do not alter the current
small-pool pilot until the PI resolves the social-pool policy.

## Known Limitations and Required Validation

- Windows Psychtoolbox reported beam-position/VBL and missed-flip warnings on
  `lab_120`; treat stimulus-onset timing as unvalidated until a photodiode plus
  TTL test and `PerceptualVBLSyncTest` pass.
- The current task has no neural-data export. Preserve acquisition-system data
  and digital event timestamps separately, then align its TTL clock to the EDF
  `SegOn`/`SegOff` messages.
- The task is intentionally exploratory. Do not use it for balanced
  category-transition inference until randomization and stimulus QC decisions
  are finalized.
