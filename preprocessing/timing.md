# exp00 timing: what the event times in the neural data do and do not mean

Written 2026-11-25 from the four October 2026 movie recordings (10-09, 10-10, 10-11, 10-12). Numbers are
measured unless marked as an estimate. The checks can be re-run with the "timing check" cell of
`exp00_psth_explore.py`.

## The chain from a video frame to a spike time

1. The task (`Code/exp00_pilot_interleave/RUN_exp00_pilot.m`, function `playOneSegment`) draws the first frame
   of a segment and calls `Screen('Flip')`. When that returns it sends a 50 ms pulse on the "segment on" line.
   A pulse on the "segment off" line follows when the segment stops.
2. The NI box records the pulses (`*.nidq.bin`, last column, bit 2 = on, bit 0 = off, bit 3 = pause) on its own
   clock, about 10.6 kHz.
3. The probe records spikes (`*.ap.bin`) on a second clock, about 30 kHz.
4. An event time has to be moved from the NI clock to the probe clock before it can be compared with spikes.

Each step adds an error. From largest to smallest:

## 1. Pulse to light on the screen: unknown, tens of ms, roughly constant

The pulse is sent after the frame is handed to the graphics card, not when the monitor shows it. In
`segment_diagnostics.csv` every frame of every segment is flagged as a missed flip (`MissedFlips` equals
`MovieFrames`), which is the known Psychtoolbox sync failure on this rig (`docs/PICKUP.md`). So Psychtoolbox's
own time stamps cannot be trusted, and there is no photodiode recording.

- Estimate: light follows the pulse by 1 to 3 frames, some tens of ms, plus the monitor's own delay.
- Effect: response latencies read from a PSTH are too short by that amount. Differences between conditions
  are not affected, because the delay is the same for all of them.
- Fix: a photodiode on a corner of the screen, recorded on a spare NI analog channel. Until then, quote
  latencies as "from the TTL".

## 2. Gaps between segments: about 0.5 s, variable

B does not cut straight from A. After each segment the next video has to be cued to its start point, and the
pulses show how long that takes:

| session | segment length (median, range) | A off to B on | B off to next A on |
|---|---|---|---|
| 10-09 | 2008 ms, 1817 to 2023 | 500 ms, 158 to 3740 | 650 ms, 275 to 1766 |
| 10-10 | 2009 ms, 1817 to 2036 | 475 ms, 197 to 1124 | 675 ms, 258 to 1183 |
| 10-11 | 2009 ms, 1862 to 2034 | 487 ms, 181 to 1709 | 673 ms, 275 to 2099 |
| 10-12 | 2009 ms, 1401 to 2034 | 467 ms, 158 to 1507 | 625 ms, 267 to 1475 |

- From the task code, nothing is drawn during the gap, so the last frame of the previous segment should stay
  frozen on screen. Only the first segment of a trial follows a grey screen. This has not been confirmed by
  watching the rig.
- A trial therefore lasts about 15 s, not 12 s, and the time from one onset to the next varies from trial to
  trial. Anything aligned to an onset is fine; anything that assumes a fixed 2 s rhythm is not.
- A few segments are short (1.4 s on 10-12, 1.8 s elsewhere). Use the off pulse, not "onset + 2 s", for
  anything about the end of a segment.
- The seek time is also in `segment_diagnostics.csv` (`SeekToFirstFrame_ms`).

## 3. NI clock to probe clock: under 1 ms with the method now used

The two boxes count samples independently. SpikeGLX can record a shared 1 Hz square wave on both to tie them
together; it was **off on 10-09, 10-10 and 10-11 and on for 10-12**. Keep it on for every new recording.

Measured on 10-12, where the square wave gives the true answer:

| method | error at the start | error at the end (40 min) |
|---|---|---|
| start sample and sample rate from the two `.meta` files (`exp00_segments.py`) | 5.0 ms | 7.6 ms |
| assume both files start and stop together, place events by fraction of the file (`exp00_psth_explore.py`) | 0.1 ms | 0.9 ms |

- The header method is wrong mainly because `niSampRate` in the header (10593.4) is a rounded value; measured
  against the square wave it is 10593.358.
- On the three sessions without the square wave the header method cannot be checked directly. The two files'
  durations disagree by 9 to 11 ms there, which is the size of error to expect from it by the end.
- The square-wave edges on 10-12 could be used for an exact alignment (this is what the SpikeGLX tool TPrime
  does). Not done, since the simpler method is already under 1 ms.

## 4. Kilosort window rounds the sample rate

Sorting through the Kilosort window stores `sample_rate = 30000.0` in `params.py` although the probe header
says about 30000.45. Spike times are stored as sample numbers, so the sort is fine, but converting to seconds
with the rounded rate is off by 35 ms after 39 minutes. Always take `imSampRate` from the `ap.meta`. The five
overnight sorts were run headless and carry the exact rate.

## 5. Things that are fine

- Pulse counts match the task log exactly in all four sessions (1080, 546, 1080, 576 segments), so segments
  are labelled by order with no ambiguity.
- The pulse when a paused session resumes is not recorded; nothing depends on it.
