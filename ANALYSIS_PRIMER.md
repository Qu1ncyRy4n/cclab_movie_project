# Analysis Primer — Eye-Tracking & Neural Data for the Movie Free-Viewing Task

Written for someone new to this. It starts with the data you actually have
(eye movements during movie watching) and then previews the neural-recording
methods a lab like this usually adds next. You don't need all of this on day
one — read Part 1, skim the rest.

---

## Part 0: The mental model

Every analysis here answers one of three questions:

1. **Where/when did the animal look, and at what?** (behavior — eye movements)
2. **Does looking depend on the condition?** (does social vs. nature change
   gaze?)
3. **Later: what were neurons doing while this happened?** (neural coding)

Almost everything below is a tool for one of those. Keep asking "which question
is this serving?" — it stops you drowning in method names.

---

## Part 1: The data you have now (eye tracking)

### What the EyeLink actually records
- **Samples**: eye position (x, y) at a fixed rate (typically 500 or 1000 Hz),
  plus pupil size. This is the raw stream in the `.edf` file.
- **Events**: the tracker also auto-labels *fixations*, *saccades*, and
  *blinks*. You can use these or re-detect them yourself.
- **Messages**: text markers your script inserted (`ImageOn_N`, `DotOff_N`,
  etc.). These are how you line up gaze with what was on screen.

Coordinates are in **screen pixels**. To interpret them you need the
pixels-per-degree (`ppd`) from the config geometry, and the movie's on-screen
rectangle (`ImageRect` in the Results table) to know where the movie was vs.
the grey border.

### Step 1 — Getting the data out
The `.edf` is a proprietary binary. Two routes:
- `edf2asc` (EyeLink command-line tool) → plain-text ASCII you can parse.
- A MATLAB/Python EDF reader (e.g. the `edfread` MATLAB function, or Python
  `pyedfread`). These give you sample arrays + event tables directly.

The `.mat` `Results` table (trial-level: which movie, success, timing markers)
is your **trial index** — join it to the gaze stream on trial number.

### Step 2 — Cleaning (do not skip)
- **Blinks / signal loss**: pupil drops to 0 or coordinates go off-screen.
  Remove these windows; optionally interpolate short gaps (<~100 ms).
- **Drift**: the eye signal can slowly shift over a session. The task does a
  drift correction at calibration, but check that fixations still cluster on
  the fixation point at trial start.
- **Calibration quality**: bad calibration = every spatial result is garbage.
  Sanity-check by plotting gaze during the enforced-fixation phase — it should
  sit tightly on the dot.

### Step 3 — Event detection (fixations & saccades)
A **fixation** = eye roughly still; a **saccade** = fast jump between them.
Free-viewing analysis is mostly about the sequence of fixations ("where did it
look, in what order, for how long").
- Use EyeLink's built-in events to start. If you need control, the standard
  algorithm is **velocity-based (I-VT)**: compute eye velocity per sample,
  label samples above a threshold as saccade, below as fixation. Engbert &
  Kliegl's microsaccade detector is the common reference implementation.
- Outputs per fixation: onset time, duration, (x, y) location.

### Step 4 — The core behavioral measures
For each trial (and each movie category), compute:
- **Fixation duration** distribution — longer fixations ≈ more engagement.
- **Saccade rate / amplitude** — how actively the animal scans.
- **Dwell time on regions of interest (ROIs)** — e.g. time spent on faces vs.
  background. This is where the *social vs. nature* hypothesis lives.
- **Spatial dispersion / entropy of gaze** — focused vs. exploratory looking.
- **Time-to-first-fixation** on a region (e.g. how fast it looks at a face).

### Step 5 — Regions of interest & saliency
Your scientific question ("do they look at socially relevant content?") needs
you to define *what* they looked at:
- **ROIs**: mark regions in the movie (faces, bodies, moving objects). For
  video this means per-frame annotation — labor-intensive by hand, so people
  use face/body detectors (e.g. an off-the-shelf detector run per frame) to
  auto-generate ROI masks. Then: fraction of fixations falling in each ROI.
- **Saliency models**: predict where a "generic" viewer looks based on
  low-level image features (contrast, motion). Comparing actual gaze to a
  saliency map separates "looked because it's bright/moving" from "looked
  because it's social."

### Step 6 — Comparing conditions (the stats)
You have 3 movie types, interleaved. Typical tests:
- Per-animal, per-category averages → compare with ANOVA or mixed-effects
  models. **Mixed-effects (random intercept per animal, per movie)** is the
  right tool once you have >1 subject and many movies — it respects that
  movies and animals are sampled, not fixed.
- Because gaze unfolds in time, you'll often compare **time-courses** (e.g.
  proportion looking at faces over the movie timeline) rather than one number.
  Cluster-based permutation tests handle "which time windows differ" without
  paying a penalty for testing every millisecond.
- **Watch the confounds**: reward, fixation-hold requirement, and movie
  luminance all differ from pure free viewing. Match or regress these out.

### Reality checks specific to *this* task
- Reward is gated only on the first 0.8 s (dot-on-movie). After that it's true
  free viewing — analyze those two phases separately.
- Aborted trials still get logged (`TrialSuccess=0`, `AbortPhase` set). Decide
  up front whether to include partial trials.
- The fixation acceptance window is a **square**, and gaze during the enforced
  phase is not free — don't mix it into free-viewing gaze stats.

---

## Part 2: When neural recordings get added

Cognitive-control labs usually pair this behavior with electrophysiology
(single units / multi-unit / LFP via Utah arrays, linear probes, or Neuropixels)
or sometimes calcium imaging. The behavioral markers you already save become
the alignment backbone. Here's the vocabulary you'll meet.

### Spikes (action potentials)
- **Spike sorting**: raw voltage → individual neurons' spike times. Tools:
  Kilosort, MountainSort. Output = spike times per unit.
- **Firing rate**: spikes per second. Two ways to get a continuous rate:
  bin-and-count (histogram) or convolve spike times with a smoothing kernel
  (Gaussian). This is the fundamental signal.
- **PSTH (peri-stimulus time histogram)**: average firing rate aligned to an
  event (e.g. `ImageOn`). "What does this neuron do when the movie starts?"
  Your EyeLink messages are exactly these alignment events.
- **Raster plot**: one row per trial, a dot per spike. The visual companion to
  the PSTH.
- **Tuning**: does firing rate depend on a variable (movie category, gaze
  location, reward)? Compare rates across conditions.

### LFP / continuous signals
- **Local field potential**: low-frequency voltage, reflects population/synaptic
  activity. Analyzed in the **frequency domain** — power spectra, band power
  (theta, gamma), and **spike-field coherence** (do spikes lock to an
  oscillation phase?). Standard toolboxes: Chronux, FieldTrip.

### Population-level methods (where the field is now)
Once you have many neurons, single-neuron tuning gives way to population
geometry:
- **Dimensionality reduction** (PCA, and nonlinear: t-SNE, UMAP): summarize
  many neurons as a few "population activity" axes. Useful for visualizing how
  neural state moves through a trial.
- **Decoding / population classifiers**: train a model (often just linear /
  logistic regression or SVM) to predict the condition (social vs. nature) from
  neural activity. "Is the information there, and when?" Decoding accuracy over
  time is a very common figure.
- **Encoding models / GLMs**: predict each neuron's firing from task + gaze
  variables. A Poisson GLM with predictors (movie category, gaze position,
  reward, time) tells you what each neuron is "about" while controlling for
  correlated variables — important here because gaze and stimulus are entangled.
- **Representational similarity analysis (RSA)**: compare the *pattern* of
  responses across conditions rather than individual neurons.

### The special trick for free viewing: gaze-contingent analysis
In free viewing the stimulus on the fovea changes every fixation. So people
align neural activity to **fixation onsets** (not just stimulus onset) and ask
what the neuron encodes about *the thing just fixated*. This turns each fixation
into a mini-trial. Your fixation-detection work from Part 1 feeds directly into
this. It's the natural bridge between the eye data and future neural data.

---

## Part 3: Practical toolchain

| Need | Common tools |
|---|---|
| Read EDF | `edf2asc`, `edfread` (MATLAB), `pyedfread` (Python) |
| Eye events | EyeLink built-in, or I-VT / Engbert-Kliegl detectors |
| Stats | MATLAB `fitlme` (mixed models); Python `statsmodels`, `pingouin` |
| Neural (MATLAB) | FieldTrip, Chronux |
| Neural (Python) | `spikeinterface`, Kilosort, `elephant`, `neo`, MNE |
| Data standard | **NWB (Neurodata Without Borders)** — worth adopting early; it
  co-stores spikes, LFP, eye tracking, and trial events in one file |

**Language reality**: the acquisition code here is MATLAB, and much monkey-ephys
tooling is MATLAB (FieldTrip, Chronux). Modern spike sorting and ML-flavored
analysis has moved to Python. You'll likely straddle both. That's normal.

---

## Part 4: If you read nothing else

1. Get the gaze out of the EDF and confirm calibration is good (plot fixation
   on the dot). Everything rests on this.
2. Detect fixations/saccades; compute dwell time on ROIs per movie category.
3. Compare categories with a mixed-effects model, treating movies and animals
   as random effects.
4. Keep the enforced-fixation phase separate from free viewing.
5. When neural data arrives, your saved EyeLink event markers are the alignment
   spine — PSTHs and decoding hang off them.

### A short reading list
- Holmqvist et al., *Eye Tracking: A Comprehensive Guide to Methods* — the
  eye-tracking bible.
- Dayan & Abbott, *Theoretical Neuroscience* — firing rates, tuning, decoding
  foundations.
- Cunningham & Yu (2014), "Dimensionality reduction for large-scale neural
  recordings" — the population-analysis mindset.
- Engbert & Kliegl (2003) — microsaccade / fixation detection.
