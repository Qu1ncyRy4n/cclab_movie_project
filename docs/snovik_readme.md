Original rotation notes from S. Novik. Preserved for context — see `../README.md`
for the current up-to-date documentation.

---

This folder contains initial work on the movie project from my rotation!

## **What's in the Bliss-Moreau_Machado_Videos folder:**

> **Note (2026-07-16):** The per-category subfolders (`video_nature/`,
> `video_social_directed/`, `video_social_undir/`) are no longer required on
> disk. Category membership is now read from `video_ebm_dataset/MANIFEST.csv`
> in the repo, and all videos are loaded from `video_all/` only. Update
> `paths.cfg` to point at the `video_ebm_dataset/` folder containing
> `video_all/`. See `../README.md` → "Movie selection / randomization".

Videos and code (all of these are needed to run the movie viewing paradigm):

- **video_all**: All the initial videos from the Bliss-Moreau_Machado dataset
- ~~**video_nature**~~, ~~**video_social_directed**~~, ~~**video_social_undir**~~:
  These subfolders are no longer needed — category membership is tracked in
  `MANIFEST.csv` instead.
- **Code**: All code needed to run the movie paradigm
  - **CONFI_freeviewingTraining_movie.m**: Parameters file. Key parameters:
    - **cclab.moviespertype**: Movies per category. Total shown = 3 × moviespertype.
    - **cclab.filepath**: Set in `paths.cfg` (copy from `paths.cfg.template`).
      Must point to `video_ebm_dataset/`, which must contain `video_all/`.
  - **RUN_freeviewingTraining_movie.m**: Run this file to run the paradigm!
  - **pseudorandomization.m**: Randomizes movie order so every block of 3
    contains one from each category. Reads category membership from MANIFEST.csv.
    To add boundary videos: extend MANIFEST and add a 4th category here.

Other stuff:

- **Pilot data**: Eye-tracking data from initial experiment with Vennie
  (now in `Data/Pilot data/`)
- **video_boundary** and **video_clipped**: Attempts at creating boundary videos
  using online clipping tools. Approach: keep a `video_boundary/` folder of
  pre-made boundary clips and add it as a 4th category in pseudorandomization —
  same pattern as the other categories. Add a `video_boundary` column to
  MANIFEST.csv to track membership.
