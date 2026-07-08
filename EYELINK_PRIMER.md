# Quick EyeLink Primer

A fast orientation to the EyeLink eye tracker used in this project. Enough to
understand the code, the data, and the jargon. Written from SR Research's
EyeLink 1000/1000-Plus conventions (the common lab models).

## The hardware, in one paragraph
An EyeLink is a **video-based, infrared eye tracker**. An IR illuminator lights
the eye; a high-speed camera images it; onboard software finds the **pupil** and
the **corneal reflection** (CR, the glint of the IR source on the cornea). The
vector between pupil and CR gives gaze direction robustly against small head
movements. Sampling is fast — **500 or 1000 Hz** — which is why it's the
standard for precise fixation/saccade timing.

## Two-computer setup
EyeLink runs on **two PCs**, and the code reflects this:
- **Host PC**: dedicated box running the tracker. Does the actual eye
  detection, stores the raw recording, shows the camera image for setup.
- **Display PC**: your experiment machine running MATLAB + Psychtoolbox. Talks
  to the Host over Ethernet via the `Eyelink(...)` command API.

Every `Eyelink('Command', ...)` in the code is the Display PC configuring the
Host. `dummymode` in the config bypasses all this and uses the mouse instead,
so you can develop without a tracker.

## Calibration & validation (why it matters)
The tracker outputs raw pupil/CR positions; it must learn the mapping to
**screen coordinates**. That's calibration:
- **Calibration**: animal looks at a grid of dots (this task uses `HV9` = a
  horizontal-vertical 9-point grid). The tracker fits the raw→screen mapping.
- **Validation**: repeat, measure error in degrees. Good validation ≈ <0.5°.
- **Drift correction / drift check**: a single-point re-check during the session
  to catch slow shifts. This task enables online drift correction around screen
  center.

If calibration is bad, **every spatial number downstream is wrong.** First
sanity check on any dataset: does gaze sit on the fixation dot during the
enforced-fixation phase?

## Coordinate system
- Screen coordinates in **pixels**, origin **top-left**, y increases
  **downward** (standard raster convention — note this when doing geometry;
  the task builds fixation windows as `centerY - y` to flip into this space).
- The code tells the Host the screen size via `screen_pixel_coords`, so Host
  and Display agree on pixels.
- Convert pixels to **degrees of visual angle** with the `ppd` (pixels per
  degree) from viewing distance + screen width — see the ANALYSIS_PRIMER.

## What lands in the data
Three streams, all in the `.edf`:
1. **Samples** — raw timestamped gaze (x, y) + pupil size, at the sampling rate.
   The `file_sample_data` command picks which fields are saved (this task saves
   GAZE, HREF, RAW, AREA, and more).
2. **Events** — the Host auto-detects and labels **fixations, saccades,
   blinks** (`file_event_filter`). Saves you writing a detector, though you can
   re-detect from samples for control.
3. **Messages** — arbitrary text the experiment inserts to mark what happened.
   This code writes `TrialStart_N`, `FixInFP_N`, `ImageOn_N`, `DotOff_N`,
   `Reward_N`. **These are your alignment anchors** — they're how you know which
   samples correspond to "movie on screen."

## Key terms glossary
| Term | Meaning |
|---|---|
| **Pupil-CR** | the two features tracked; their vector = gaze, robust to head motion |
| **GAZE** | eye position in screen pixels (what you usually want) |
| **HREF** | head-referenced angular coords (before screen mapping) |
| **RAW** | uncalibrated pupil/CR camera coords |
| **AREA** | pupil size (arbitrary units unless separately calibrated) |
| **Sample** | one timestamped measurement at the tracking rate |
| **Event** | a detected fixation/saccade/blink with start, end, properties |
| **Message** | experiment-inserted text marker in the recording |
| **Drift** | slow accumulating offset in the gaze signal over a session |
| **HV9** | 9-point horizontal-vertical calibration grid |
| **EDF** | EyeLink Data File — proprietary binary holding all of the above |

## The `.edf` file
Proprietary binary. It's transferred from Host → Display at session end (the
`Eyelink('ReceiveFile', ...)` calls). To analyze:
- `edf2asc` (SR Research CLI) → text, or
- `edfread` (MATLAB), `pyedfread` (Python) → arrays + event/message tables.

## Programming API (Psychtoolbox side)
The command patterns you'll see in `RUN_freeviewingTraining_movie.m`:
- `EyelinkInit` / `EyelinkInitDefaults(window)` — connect, set the `el` defaults
  struct (colors, target size, beeps).
- `Eyelink('OpenFile', name)` — start an EDF on the Host (≤8-char name — hence
  the subID length check).
- `Eyelink('Command', '...')` — configure Host (filters, calibration type,
  coords).
- `EyelinkDoTrackerSetup(el)` — enter camera-setup/calibration UI.
- `Eyelink('StartRecording')` / `'StopRecording'` — bracket the session.
- `Eyelink('NewestFloatSample')` — pull the latest gaze sample online (this is
  what `checkFixation` uses for real-time, gaze-contingent fixation checks).
- `Eyelink('Message', '...')` — insert an alignment marker.
- `Eyelink('CheckRecording')` — watch for the tracker dropping out mid-session.
- `Eyelink('ReceiveFile', ...)` / `'CloseFile'` / `'ShutDown'` — save & tear
  down.

## Gotchas
- **8-character filename limit** on the Host EDF (old FAT-style constraint).
- **Binocular vs. monocular**: `EyeAvailable` returns 0/1/2; this code forces
  the right eye when binocular. Know which eye your data is.
- **Pupil size ≠ real units**: it's affected by luminance — keep background
  luminance matched (the task sets calibration background to grey for this
  reason) if you care about pupillometry.
- **Blinks corrupt gaze**: pupil is lost, x/y go wild. Always remove blink
  windows before spatial analysis.
- **Dummy mode is mouse, not eye** — timing and noise characteristics differ;
  use it only for logic testing.

## Official docs
- *EyeLink 1000 Plus User Manual* and *EyeLink Programmers Guide* (SR Research;
  ships with the toolbox / on the support forum). The Programmers Guide is the
  authoritative reference for every `Eyelink(...)` command above.
