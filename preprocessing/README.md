# Preprocessing notes for the exp00 movie recordings (private)

Moved here on 2026-11-25 from `cclab-neurophys-preproc-pipeline` so that repo can become public. Everything in
this folder names real sessions, machines or people and must stay private.

| file | what it is |
|---|---|
| `pickup.md` | where the October 2026 movie sorting stands and what to do next |
| `TODO.md` | task list and open decisions (as of 2026-11-23, partly superseded by `pickup.md`) |
| `data-transfer.md` | the copy commands actually used on the lab sorting PC, with its drives and paths |
| `sorting-pc-notes.md` | the pipeline repo's known-issues file before it was generalised (sorting-PC traps, exp00 notes) |
| `PUBLIC_RELEASE.md` | audit of the pipeline repo and what is left before it can be published |
| `exp00_segments.py` | TTL edges in `nidq.bin` + `event_log.csv` -> one labelled row per movie segment |
| `exp00_psth.py` | sanity plot: firing rate around segment onset (never run) |
| `exp00_psth_explore.py` | `# %%` first-look PSTHs for all four sessions, one cell per figure: by category, trial position, segment number, whole trial, one unit's raster. Usage is in its header |
| `timing.md` | what the event times mean: pulse vs light on screen, gaps between segments, clock alignment |
| `test_exp00_segments.py` | test for the segment table (imports need adjusting: it was written for the package layout) |
| `configs/` | session configs for real sessions (pipeline-repo format) |
| `scratch/` | hand-written `# %%` walkthrough of the raw 10-10 recording |

Links inside `pickup.md` and `TODO.md` to `design.md`, `known-issues.md` and `pipeline.md` refer to the `docs/`
folder of the pipeline repo.

## PSTHs (`exp00_psth_explore.py`)

This repo has its own environment (`pyproject.toml`), so on any machine:

```bash
uv sync
uv run python preprocessing/exp00_psth_explore.py     # every figure, every session
```

or open the file in Zed and run it cell by cell (kernel `cclab-movie (.venv)`; register it once with
`uv run python -m ipykernel install --user --name cclab-movie --display-name "cclab-movie (.venv)"`).

### Getting the data onto the Mac (0.6 GB)

The script needs only a few small files per session. On the sorting PC, in PowerShell, copy just those to the
NAS, keeping the folder layout (change the destination if you prefer another place):

```powershell
robocopy D:\Quincy\data\neuropixel\venni R:\shared\current\Neuropixel\_exp00_psth_bundle `
    spike_times.npy spike_clusters.npy templates.npy channel_positions.npy channel_map.npy `
    cluster_KSLabel.tsv *.ap.meta segments_exp00.csv `
    /S /R:5 /W:15 /XD kilosort4_test300 kilosort4_gui_test _figures `
    D:\Quincy\data\neuropixel\venni\venni_20261009_SEF\movie\raw\movie1_g0\movie1_g0_imec0\kilosort4
```

Then on the Mac, with the NAS mounted:

```bash
rsync -av /Volumes/cclab/shared/current/Neuropixel/_exp00_psth_bundle/ ~/dev/research/data/neuropixel/venni/
```

The script looks in `~/dev/research/data/neuropixel/venni` by itself; for any other place set
`CCLAB_MOVIE_DATA=/path/to/venni`. Figures land in `<that folder>/_figures/exp00_psth/`.

## Running the older exp00 scripts

They need only numpy, pandas and matplotlib, so borrow the pipeline repo's environment:

```bash
uv run --project <path to cclab-neurophys-preproc-pipeline> python preprocessing/exp00_segments.py \
    <SpikeGLX run folder> <event_log.csv> <out.csv>
uv run --project <path to cclab-neurophys-preproc-pipeline> python preprocessing/exp00_psth.py \
    <kilosort4 folder> <segments.csv> <out.png>
```

## Sorting every movie recording on the lab sorting PC

From a Windows shell (WezTerm or Windows Terminal), in the pipeline repo:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\sort_all.ps1 -DataRoot D:\Quincy\data\neuropixel\venni -Task movie -Venv D:\Quincy\venvs\cclab-preproc
```
