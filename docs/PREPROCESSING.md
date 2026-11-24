# Neural preprocessing — exp00

Written 2026-10-27 from a lab meeting on the Neuropixels pipeline, adapted to
the movie task. **Updated 2026-11-20** after looking at the real recordings on
the NAS: see "What the recordings show" below, which replaces the guesses in
the first draft. Lab-wide storage and naming rules
live in `../../CCLabDataOrg/CC Lab Data Organization Standard.md`; this file
covers only what is specific to exp00 and refers to that standard for the rest.

---

## Pipeline (lab standard, from the meeting)

| step | tool | input | output | notes |
|---|---|---|---|---|
| 1. Collect | SpikeGLX | probe + NI-DAQ | `<run>_g0_t0.nidq.bin/.meta`, `<run>_g0_imec0/*.ap.bin/.meta` (~30 kHz spikes), `*.lf.bin/.meta` (1–2.5 kHz LFP) | `.bin` = raw data, `.meta` = text header. 384 recording channels, picked from more electrodes than that; one bank at a time. |
| 2. Sort | Kilosort 4 | `ap.bin` + probe config (channel map) | `processed/kilosort4/` (npy/tsv, `params.py`) | Brinda has the probe-config code; it is undocumented (see open questions). No need to specify a bank. Check the channel count and sample rate against `ap.meta` before sorting. |
| 3. Curate | Phy | `cd processed/kilosort4 && phy template-gui params.py` | `cluster_group.tsv` (`good` / `mua`) | Not always needed: CCG and timescale analyses can run on the uncurated output, and timescale analysis may start from LFP. |
| 4. Align / build | `CCLabDataOrg/BuildRecordingMeta.m` | KS dir + `sync_event_codes.npy` + behavior `.mat` | `<session>_meta.mat` (the standard's grab-and-go file) | Built around MGS event codes (4 = trial start, 1 = attempt). **exp00 does not fit as-is** — see below. |

First analysis on any new session: **PSTHs as a sanity check.**

## What the recordings show (2026-11-20)

Sessions on the NAS, under `shared/current/Neuropixel/`. Behavior for every run
is also in `shared/experiment_packages/runs/exp00/<date>_<time>_exp/`.

| session folder | movie recording | behavior run | trials | sorted? |
|---|---|---|---|---|
| `100926_Venni_SEF_ACC` | `movie1_g0` (94 min, 130 GB) | `2026-10-09_124846_exp` | 180 / 180 | Kilosort 4.1.7, 267 good / 342 mua, not curated |
| `101026_V_SEF_ACC` | `Movie/Movie_g0` (39 min, 54 GB) | `2026-10-10_130828_exp` | 91, quit at 92 | no |
| `101126_Vennie_SEF_ACC` | `Movie/Movie2_g0` (84 min, 116 GB); `Movie_g0` is a 6 min false start | `2026-10-11_125148_exp` (runs folder only) | 180 / 180 | no; upload unfinished on 11-20 |
| `101226_Vennie_SEF_FEF` | `Movie/P1(FEF)` imec0 + `Movie/P2(SEF)` imec1 | `2026-10-12_120830_exp` (runs folder only) | 96, quit at 97 | no; upload unfinished on 11-20 |

The 10-07 and 10-08 runs (`100726_V_SEF`, `100826_V_FEF`) have not been looked at.

**TTL wiring, measured.** Rig config `rig-right.txt` maps A/B/C/D to NI
`port0` lines 4/3/5/7. In `nidq.bin` (8 analog channels + 1 digital word,
10593.4 Hz) they appear as bits of the digital word:

| task line | meaning | NI digital bit | value as an "event code" | recorded? |
|---|---|---|---|---|
| A | segment on | 2 | 4 | yes |
| B | segment off | 0 | 1 | yes |
| C | operator pause | 3 | 8 | yes |
| D | resume | - | - | **no edges in any recording** |

Counts match `event_log.csv` exactly on both sessions checked: 10-09 has 1080
on / 1080 off, 10-10 has 546 / 546. The values 4 / 1 / 8 are the same numbers
the MGS task uses as codes, so lab tools that read event codes will see them,
but they carry no trial or segment identity. NI analog 0-3 carry identical
400-500 ms pulses, probably reward (not confirmed).

**No sync wave.** The SpikeGLX 1 Hz sync was disabled (`syncSourceIdx=0`) for
the 10-09, 10-10 and 10-11 movie recordings, and the probe's sync channel is
constant. TPrime-style alignment is not possible. NI times are converted to
probe samples with each stream's `firstSample` and calibrated sample rate from
the meta files; expect a few ms of drift across a session (not yet measured).
Turn the sync wave on before any new collection.

**Probe geometry is in `ap.meta`** (`~snsGeomMap`): NP1032, 384 channels, one
shank. 10-09: one continuous span, 0-7.7 mm from the tip. 10-10 and 10-11: two
blocks of 192 channels, 0-3.8 mm and 7.7-11.5 mm from the tip (ACC and SEF;
which is which to be confirmed). No hand-made probe file is needed.

**Sorting off the NAS is slow.** The 10-09 sort read `ap.bin` over the network
and took 13 h. Copy the recording to a local disk first.

## Tools (in `cclab-neurophys-preproc-pipeline`)

```bash
uv sync --extra sort          # adds Kilosort 4 + PyTorch
# TTL edges + event_log.csv -> one labelled row per segment (stops if counts differ)
uv run python -m cclab_preproc.exp00_segments <SpikeGLX run folder> <event_log.csv> <segments.csv>
# Kilosort 4, probe layout taken from ap.meta; --tmax 300 = first 5 minutes only
uv run python -m cclab_preproc.sort <file.ap.bin> <results folder> [--tmax SECONDS]
# sanity plot: firing rate around segment onset
uv run python -m cclab_preproc.exp00_psth <kilosort4 folder> <segments.csv> <out.png>
```

`segments.csv` columns: trial, segment, movie (A/B), video, `t_on_s` /
`t_off_s` (seconds on the NI clock), `on_ap_sample` / `off_ap_sample` (the
units of Kilosort's `spike_times.npy`). Session config for 10-10:
`configs/npx/venni_20261010_SEF.toml`.

## Where exp00 differs from the standard

**Event markers.** exp00 sends no event codes. It drives two digital lines
through `cclabPulse` (`Code/exp00_pilot_interleave/RUN_exp00_pilot.m:781,820,878`):

| line | fires at | width | count per trial |
|---|---|---|---|
| A | first flip of each segment (`SegmentOn` in `event_log.csv`) | 50 ms | 6 |
| B | end of each segment (`SegmentOff`) | 50 ms | 6 |
| C / D | operator pause / resume (`ControlMarker`) | 50 ms | 1-2 per session; D is not recorded |

So trial and segment identity can only come from **order**: the k-th rising
edge on line A is the k-th `SegOn_<trial>_<seg>_<A|B>` message in the EDF.
`BuildRecordingMeta`'s `code_start`/`code_attempt` logic needs an exp00
adapter (or the Python port, below) that does the following:

Steps 1, 2 and 5 are done by `cclab_preproc.exp00_segments` (see Tools).
Step 4 uses the `firstSample` fallback because there is no sync wave. Step 3
(EDF clock) is still open.

1. Extract rising edges for lines A and B from `nidq.bin` (digital bits 2
   and 0, see the wiring table above).
2. Assert the counts: A = B = number of SegOn = number of SegOff in the EDF
   (1080 for Vennie 10-07), with any `ControlMarker` rows accounted for.
   **If they don't match, stop.** An ordinal match off by one silently
   mislabels every later segment.
3. Fit EDF time → neural time on paired SegOn/A and SegOff/B edges. Report
   the slope (clock drift) and the residuals; residuals should be a few ms,
   with the EyeLink message sent just before the TTL. This mapping also puts
   gaze samples on the neural clock.
4. nidq and imec are separate clocks. Map nidq edges onto the imec (spike)
   clock with SpikeGLX's sync channel (TPrime), or find out whether Brinda's
   `sync_event_codes.npy` step already does this.
5. Join trial info from the Results `.mat` and `session_plan.csv` (videos,
   categories, start times), keyed by trial number.

**Behavior files.** Trial table = `Vennie_<date>.mat` (`Results`, MATLAB
table; export once to CSV, see `data_analysis/validate_exp00_run.ipynb`),
plus `event_log.csv` and `session_plan.csv`. These sit in `raw/behavior/`.
The EDF goes in `raw/eyelink/`.

**Epochs.** The switch-gap fix is deferred (see `PICKUP.md`, 2026-10-27):
each SegOff→SegOn gap (99–733 ms, previous movie's last frame frozen on
screen) is its own epoch. Use real edge times, never a nominal 2 s grid.

**Naming under the standard.** Session `venni_20261007_<AREA>` — the area
for this session is unknown; fill it from the recording log. The standard
has no exp00 task token (`FV` is freeview). Propose `movie` or `exp00` in the
task naming table.

## Checklist per session

Status 2026-11-20: 10-10 has `segments.csv` (546 segments, counts match);
its `ap.bin` is being copied off the NAS for a first sort.

- [x] Find the SpikeGLX recordings (table above).
- [ ] From `nidq.meta` / `ap.meta`: sample rates, `nSavedChans`, 384 AP
      channels, the probe/bank used, and a file duration that covers
      13:12–14:12.
- [x] Count TTL edges on A and B against `event_log.csv` (10-09, 10-10 done).
- [ ] Fit EDF ↔ nidq ↔ imec clocks; save the mapping and the residuals.
- [ ] Kilosort 4 from a local copy (probe layout comes from `ap.meta`) → optional Phy pass.
- [ ] Sanity PSTHs: aligned to SegOn, split by A/B movie and by category
      (nature/social), and to SegOff → next SegOn (the gap epoch). Expect a
      visual onset response at segment 1A. A flat raster across all units
      means alignment is wrong before it means anything about biology.
- [ ] Build the metafile and add a `sessions.csv` row.

## Open questions from the meeting

- **Documentation:** centralize it — one place for the whole workflow
  (`CCLabDataOrg` is the obvious home). Is a "normative tooling" section
  needed?
- **Probe config:** Brinda's code generates it — get it documented and
  versioned.
- **BuildRecordingMeta:** Taylor wants to run it over the whole shared
  server. Refactor to Python? Add a working-dir shortcut to its config
  header. Hardcoded full user paths (`C:\Users\tphamel\…`) shouldn't be in
  shared code.
- **Task naming table** for the controlled vocabulary. Some older
  recordings need labels (e.g. `100926`), with annotations kept next to the
  data.
- **Historical recording table:** grid coords, guide tube and electrode
  depth, angle. MGS has 8 directions; RF mapping. FEF is directionally
  tuned (in- vs contra-direction responses are useful); SEF is tuned less
  often. Single-unit recordings serve as exploratory probes ahead of
  high-density recordings. SEF/ACC recordings: directly dorsal to SEF.
- **Process:** Claude Code and data safety (losing control over what touches
  raw data), git discipline, and making sure people understand the pipeline
  rather than running it blind. Open discussion, not settled.
- **TTL density** (from PICKUP): ~12 pulses per trial; confirm with Brinda
  that the acquisition side handles it.
