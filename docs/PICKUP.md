# Pickup — exp_01 transitions

State of play as of **2026-09-16**, written so another machine (or another
person) can continue without the conversation that produced it.

---

## 2026-09-24 — pivot: exp_00, a deliberately tiny pilot, built alongside exp_01

Everything below this point is still accurate for `exp_01_transitions` and
still the deeper design work — see `exp_01_spec.md` and
`docs/interleave_design_options_2026-09-24_0951.md` (design-space matrix +
interactive demo at `docs/demos/interleave_options_demo.html`) for that.
But real data collection is starting from something much smaller first:

- **`Code/exp00_pilot_interleave/`** (MATLAB) — 4 hand-vetted videos (2
  `nature`, 2 `social_undir`, from `MANIFEST.csv`'s `pilot_ready` column),
  no de Bruijn balancing, no `buildSequence.m`, fixation once per trial
  then a fixed interleave, unconditional reward. Own README covers the
  design and why it's this simple.
- **`psychopy_pilot/`** (Python) — the same design, built in parallel as a
  stack comparison. Template only — not run against a real PsychoPy
  install, no EyeLink/reward-hardware integration yet. Own README covers
  gaps.
- **`video_ebm_dataset/pilot_pool.csv`** — the shared 4-video pool both
  stacks read from.
- Rationale: too many open design questions (segment length, matching
  criterion, familiarity/repetition, PI's exact "interleaved" requirement)
  to settle any of them without first seeing real behavior. This pilot logs
  `TimesShownBeforeA/B` for future familiarity analysis but doesn't control
  for it yet.
- **Next**: test `exp_00` from a Windows machine in dummy mode (mouse, no
  EyeLink) — see `Code/exp00_pilot_interleave/README.md`'s Windows section
  for the `computer_name = 'win_dummy'` config case and the `.ps1`/`.bat`
  launcher scripts.

---

## Where things stand

`Code/exp01_transitions/` is a complete, runnable experiment: playlist-driven
free viewing across video transitions. It has never been run against real
videos. Two questions gate real data collection, both listed under
**Do these next**.

What was settled, with evidence in the repo:

- **All 300 social videos are exactly 30 s**; 592 of 600 videos overall are
  30 s. Eight nature videos are short (7.0 s to 29.5 s) and exclude themselves
  automatically. Evidence: `video_ebm_dataset/durations.csv`.
- **Clips are seeked in place, not split to disk.** No new files, no writes to
  the NAS, and `MANIFEST.csv` needs no new rows. Segment provenance is recorded
  per row in the results table instead.
- **Transitions and interleaving are one mechanism**, not two paradigms — the
  same segment playlist with different boundaries. One playback loop serves
  both (`cclab.mode`).

**Settled 2026-09-24** (was "believed but not yet established" at n=1 — see
`docs/cuts_analysis.md` for the full writeup):

- `cuts.csv` now exists — all 600 videos, built and committed.
- The n=1 belief was wrong on the directed/undirected split. **Directed
  videos are not continuous**: `social_directed` has the same zero-cut rate
  (10%) as `social_undir`, and the same median inter-cut gap (6.01 s) as
  `social_undir`. The spec's original "3 × 10 s" assumption was also wrong,
  same conclusion as before, now on real evidence instead of one file.
- Gaps vary a lot *across* a category (CV 0.6–0.8) but are often very regular
  *within* one video — `social_directed` especially so (near-metronomic when
  cuts occur), which may mean those are multi-camera switch artifacts rather
  than content cuts; worth checking against source material before treating
  them as meaningful transitions.
- `nature` is its own thing: fewer cuts (25% zero-cut), longer/less regular
  gaps (~7.9 s median, CV 0.78) than either social category.
- `clipDur = 6` is defensible as a single constant for the social categories;
  a per-video/per-category value would track the real structure better if
  the pipeline can support it. Decision not yet made — see `exp_01_spec.md`
  open question #1.

---

## Do these next, in this order

### 1. Settle seek accuracy — BLOCKING, ~5 min, needs MATLAB + Psychtoolbox

The dataset is encoded with x264 defaults, so keyframes sit **~8.34 s apart**
(measured: 0.00, 8.33, 16.67, 25.00). Every segment after the first is reached
by seeking mid-file. If Psychtoolbox snaps seeks to the nearest keyframe, then
asking for 2.5 s silently yields 0 s and **interleave mode plays entirely the
wrong footage with no error raised**.

```matlab
cd Code/exp01_transitions
test_seek
```

Needs no NAS and no monkey. It seeks into a bundled 30 s test pattern that has
the elapsed second burned into the picture and the same sparse GOP as the real
data, then saves each frame.

- requested 13.7 → picture reads **13** → accurate seek, the design holds
- requested 13.7 → picture reads **8** → keyframe snap, go to step 3

**Write the answer into `exp_01_spec.md`.** Everything downstream depends on it.

### 2. Build the cut catalog — DONE 2026-09-24, see `docs/cuts_analysis.md`

Produces `video_ebm_dataset/cuts.csv`: keyframe positions and scene-cut
positions for all 600 videos.

**This reads every byte of the 5.5 GB dataset.** Measured cold-read throughput
over the VPN is ~430 KB/s → about **3.6 hours**. On the lab LAN it is roughly
**2 minutes**. Run it where the files are.

```bash
# verify the tooling first — builds its own test video, touches no data
bash catalog_cuts.sh --selftest        # expect: selftest cuts: [2.000] ... selftest OK

VID=/mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all
ls "$VID"/*.mp4 | wc -l                # expect 600

bash catalog_cuts.sh "$VID"
```

The videos directory is a **positional argument to the script** — nothing to do
with `CONFI_exp01_transitions.m`, which only matters to MATLAB. Written out in
full, that last line is:

```bash
bash catalog_cuts.sh /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all
```

`cuts.csv` is written inside the repo regardless of where the videos live, so
the repo has to be cloned on whatever machine runs this.

Resumable — `cuts.csv` is its own progress ledger, so a dropped mount costs one
file, not the run. For a long run: `nohup bash catalog_cuts.sh "$VID" > catalog.log 2>&1 &`
(if you background it this way, don't `pgrep -f "catalog_cuts.sh"` to wait for
it from a wrapper script that itself contains that string in its command
line — it'll match itself and never exit. Wait on the PID instead.)

Ran on the lab machine (local disk, not NAS/VPN): 600/600 in ~5 minutes.
`cuts.csv` is committed. Joined against `MANIFEST.csv` by category with
`video_ebm_dataset/analyze_cuts.py` (needs `nix develop` for pandas — bare
`python3` isn't on `PATH` on this machine). **Full writeup:
`docs/cuts_analysis.md`.** Short version: the n=1 "directed = continuous"
belief was wrong; `clipDur = 6` is defensible for the social categories but
`nature` behaves differently. `cclab.clipDur` decision still open — see
`exp_01_spec.md` question #1.

### 3. Only if step 1 failed — re-encode with dense keyframes

Full decode + encode of 5.5 GB. Minutes on the LAN; do not attempt over the
VPN. Originals untouched.

```bash
mkdir -p "$VID/../video_all_densekey"
for f in "$VID"/*.mp4; do
    ffmpeg -v error -i "$f" -c:v libx264 -crf 20 -preset fast -g 25 \
        -c:a copy "$VID/../video_all_densekey/$(basename "$f")"
done
```

`-g 25` puts a keyframe every second, so any seek lands within a frame. Re-run
`test_seek` against one output before converting the intent into a decision.

---

## Getting a machine ready

The shell scripts here need `bash`, `ffmpeg` and `ffprobe`. **`ffprobe` ships
with `ffmpeg`** — one package gives you both, so there is nothing separate to
install. (`ffplay` is the one that is sometimes absent; nothing here uses it.)

```bash
sudo apt update && sudo apt install -y ffmpeg     # WSL / Ubuntu
ffprobe -version | head -1                        # confirm

git clone --recurse-submodules git@github.com:Qu1ncyRy4n/cclab_movie_project.git
cd cclab_movie_project
git submodule update --init          # cclab-matlab-tools; easy to forget
                                     # no SSH key on this machine? clone from
                                     # https://github.com/Qu1ncyRy4n/cclab_movie_project.git

bash probe_durations.sh --selftest
bash catalog_cuts.sh   --selftest
```

If a self-test fails, stop: that is an ffmpeg build problem, not a data
problem, and running against the real dataset will not tell you anything.

### Mounting the NAS from WSL

```bash
sudo mkdir -p /mnt/cclab
sudo mount -t drvfs '\\cns-nas.ucdavis.edu\cclab' /mnt/cclab
ls /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all | head
```

The mount does not survive a reboot. Re-run it, or add it to `/etc/fstab`.

### Rebuilding WSL from scratch

Only worth doing if the existing install is actually broken — for the catalog
job the requirement is just bash + ffmpeg + a NAS mount. From an admin
PowerShell:

```powershell
wsl --list --verbose             # what is installed now
wsl --unregister Ubuntu          # DESTROYS that distro's filesystem — export anything you want first
wsl --install -d Ubuntu
```

Then re-run the block at the top of this section. Nothing in this repo lives
inside WSL's filesystem, so a rebuild costs you the clone and the apt install,
nothing more.

**Or skip WSL entirely.** Nothing about the catalog job requires it — a Windows
ffmpeg build (`winget install Gyan.FFmpeg`) plus a PowerShell port of
`catalog_cuts.sh` would do the same work. The script is two ffmpeg invocations
in a loop. Ask if you want that version written.

In MATLAB:

```matlab
cd Code/exp01_transitions
buildSequence('selftest')            % de Bruijn balance + segment maths, no files
```

### Getting the videos locally

The videos are **not** in the repo and never will be (5.5 GB, gitignored). They
live on the NAS at
`\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all\`.

**You may not need a local copy.** Two different needs:
- *the catalog job* — no copy required. On the lab LAN, point `catalog_cuts.sh`
  straight at the NAS path and skip the 5.5 GB transfer entirely.
- *running the experiment* — yes, copy. A NAS hiccup mid-playback drops frames.

Convention for a local copy is **`C:\cclab_data\video_ebm_dataset\`** — off the
Desktop so OneDrive never tries to sync 5.5 GB, outside the repo, and laid out
exactly like the NAS share so nothing else has to change.

**On Windows (including a Remote Desktop session), use `robocopy`** — it is
native, resumable, and rsync writing to `/mnt/c` through WSL's drvfs layer is
slow enough to matter across 5.5 GB.

```powershell
# Windows, resumable, skips files already copied
robocopy "\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset\video_all" ^
         "C:\cclab_data\video_ebm_dataset\video_all" /E /Z /XO /R:3 /W:5
```

Only if you are working from a Linux/macOS shell and the destination is a real
Linux filesystem (not `/mnt/c`):

```bash
rsync -avP --partial \
  /mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset/video_all/ \
  /mnt/c/cclab_data/video_ebm_dataset/video_all/
```

Verify, then point MATLAB at it:

```bash
ls /mnt/c/cclab_data/video_ebm_dataset/video_all/*.mp4 | wc -l    # expect 600
du -sh /mnt/c/cclab_data/video_ebm_dataset/video_all              # expect ~5.5G
```

```matlab
cclab.video_source = 'local';   % in CONFI_exp01_transitions.m
```

Over the VPN a cold read runs at ~430 KB/s, which is too slow to stream a movie
at all — off-site, `'local'` is the only workable setting.

If the NAS is not mounted in WSL:

```bash
sudo mkdir -p /mnt/cclab
sudo mount -t drvfs '\\cns-nas.ucdavis.edu\cclab' /mnt/cclab
```

---

## Map of what is where

| path | what it is |
|---|---|
| `Code/exp01_transitions/` | the experiment — see its own `README.md` for usage |
| `Code/exp01_transitions/test_seek.m` | the blocking check in step 1 |
| `Code/RUN_freeviewingTraining_movie.m` | the original pilot task, untouched, still runnable |
| `probe_durations.sh` | header-only duration probe (cheap; already run) |
| `catalog_cuts.sh` | keyframe + scene-cut catalog (expensive; step 2) |
| `video_ebm_dataset/durations.csv` | 600 measured durations |
| `video_ebm_dataset/MANIFEST.csv` | category membership per video |
| `exp_01_spec.md` | the spec, decisions log, and the open-questions list |

## Open questions live in the spec

`exp_01_spec.md`, section **Still open** — seven items, of which the two above
are the blocking ones. Put what you learn there rather than in a chat log.

## Loose ends worth knowing

- `video_clipped` (21 rows) and `video_boundary` (3 rows) in `MANIFEST.csv`
  describe files that exist nowhere — not on the NAS, not in the repo. Per
  `docs/snovik_readme.md`, they were abandoned attempts at boundary stimuli.
  Delete the rows unless the boundary idea is being revived.
- The README's TODO list still claims the TTL pulses are commented out. They
  are live in `Code/RUN_freeviewingTraining_movie.m`. The note is stale.
- Interleave mode fires ~8 TTL pulse pairs per trial where the pilot fired 1.
  Confirm with Brinda that the Neuropixel side tolerates that density before
  real collection.
- The PTB VBL sync failure on `lab_120` (DWM compositor) is inherited from the
  original task and still unresolved. It affects timing precision either way.
