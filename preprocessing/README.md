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
| `test_exp00_segments.py` | test for the segment table (imports need adjusting: it was written for the package layout) |
| `configs/` | session configs for real sessions (pipeline-repo format) |
| `scratch/` | hand-written `# %%` walkthrough of the raw 10-10 recording |

Links inside `pickup.md` and `TODO.md` to `design.md`, `known-issues.md` and `pipeline.md` refer to the `docs/`
folder of the pipeline repo.

## Running the exp00 scripts

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
