# Making cclab-neurophys-preproc-pipeline public: audit (2026-11-25)

Decided 2026-11-25: publish as a **new repository started from one clean commit**, later, not yet. The current
repository stays private as the working copy. Cleanup is on its branch `public-prep`.

## Done on `public-prep`

- Animal names replaced by `subj01` / `subj02` in code, tests, docs, configs and notebooks. The code no longer
  holds a list of animal names (any lowercase name is accepted), so real names live only in private configs.
- Project-specific material moved to this folder: pickup notes, TODO, real session configs, scratch, exp00 code.
- Hostnames, the file-server address, drive-letter folders named after people and a Windows username removed
  from the docs, `matlab/BuildRecordingMeta.m` and `scripts/catgt/*.bat` (replaced with placeholders).
- `scripts/sort_all.ps1` takes `-DataRoot` and `-Task` as required arguments (no personal defaults).
- README: Acknowledgments section and a table of lab-original code.
- All 17 tests pass, including the notebooks on synthetic data.

## Blockers before publishing

1. **History.** The private repository's commits contain the animal's name (about 146 lines), PC hostnames, the
   file-server address and people's folder paths. Never make the existing repository public; export the tree of
   `public-prep` into a new repository as a single commit.
2. **Licence.** There is none. Without one nobody may legally reuse the code. The PI chooses (MIT or BSD
   3-Clause are the usual choices), and should check whether the university has a say.
3. **Permission and credit.** Confirm with each person that their code may be published and how they want to be
   named: `matlab/BuildRecordingMeta.m`, `make_kilosort4_probe_from_meta.py`, `scripts/catgt/*.bat`, the two MI
   notebooks. The README currently thanks Taylor, Brinda, Orhan, Wenqing and Xiaomo by first name without saying
   who wrote what; fill in full names and roles once confirmed.
4. **MI notebooks.** They are analysis, not preprocessing, were already queued for removal, and still contain
   old data paths with real session dates. Remove them (with their test, the `[mi_classification]` config
   sections and the dependencies only they need) or get their author's agreement to publish them.
5. **Third-party code.** `scripts/catgt/*.bat` derive from the batch files shipped with CatGT, which has no
   licence file. Either drop them (`catgt.py` builds the same commands) or keep them clearly marked as examples.

## Worth doing, not blocking

- Session dates remain in examples (`subj01_20250731_SEF`, `cfg.date = '040825'`). They are harmless without the
  animal's name; swap for obviously made-up dates if the lab prefers.
- The README clone URL and the package name carry the lab's GitHub organisation and "cclab". Fine if the lab is
  publishing it under its own name; update the URL to the new repository.
- `configs/local.example.toml` shows `/Volumes/cclab/shared/data` as an example path.
- `docs/design.md` describes features that are not built; label it clearly or leave it out of the first release.
- Rename `provenance.py` to `run_record.py`, convert `Build_Recording_Meta.ipynb` to a `# %%` file (queued).
- A `docs/setup.md` for a new user, and a `CONTRIBUTING` note that real session configs, hostnames and animal
  names must not be committed.
- A check in CI or a pre-commit hook that fails if a real animal name or hostname appears.
