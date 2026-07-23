# Octave Compatibility Notes

Running the paradigm under Octave (Linux) is a future goal. This doc tracks
known incompatibilities and proposed fixes.

## Status
Not yet attempted beyond initial run. PTB for Octave not yet installed.

## Known Incompatibilities

### 1. Psychtoolbox
PTB supports Octave on Linux but must be installed separately from the MATLAB
version. Install via the NeuroDebian package or PTB's GitHub installer.
After install, PTB must be loaded each session: `pkg load psychtoolbox`.
Consider adding to `~/.octaverc`.

### 2. `readtable` / `table` / `struct2table` (HIGH IMPACT)
Octave does not have MATLAB's `table` type. Affects two places:

- **`pseudorandomization.m`** — uses `readtable(manifest)` to read MANIFEST.csv
  and accesses columns by name (`T.filename`, `T.(colName)`).
  Fix: replace with a simple CSV reader using `textread` or `fgetl` loop.

- **`RUN_freeviewingTraining_movie.m`** — `Results` is a MATLAB `table`; rows
  appended with `struct2table`. Fix: use a struct array instead, save as
  struct with `save()`.

### 3. String type (`string()` / `"..."`)
MATLAB's `string` class doesn't exist in Octave. Double-quoted strings are
just char arrays.

- `state == "Movie_present"` — string comparison with `==` won't work.
  Fix: replace with `strcmp(state, 'Movie_present')` throughout.
- `string({allFiles.name}')` in `filterByCategory` — use `{allFiles.name}'`
  directly (already a cell of chars).
- `cclab.computer_name = 'dev_wsl'` — already uses single quotes, fine.

### 4. `inputdlg`
Available in Octave but requires a GUI backend (`octave-qt` or similar).
On a headless Linux rig, may need a fallback to `input()` prompt.

### 5. `datestr`
Works in Octave.

### 6. `nargin` in nested functions
`cleanup()` uses `nargin > 0` to switch between `Screen('CloseAll')` and
`sca`. Works in Octave.

## Suggested Approach

1. Install PTB for Octave — confirm `Screen` is available.
2. Fix `readtable` in `pseudorandomization.m` — highest impact, blocks startup.
3. Fix `table` / `struct2table` in `RUN_` — replace with struct array.
4. Global replace `string ==` comparisons with `strcmp`.
5. Test with `dummymode = 1` on Linux desktop before real rig.
