This folder contains initial work on the movie project from my rotation!

## **What's in the Bliss-Moreau_Machado_Videos folder:**

Videos and code (all of these are needed to run the movie viewing paradigm):

- **video_all**: All the initial videos from the Bliss-Moreau_Machado dataset
- **video_nature**: The subset of videos that are of nature scenes
- **video_social_directed**: The subset of videos that are of socially directed scenes
- **video_social_undir**: The subset of videos that are of social non-directed scenes
- **Code**: All code needed to run the movie paradigm
  - **CONFI_freeviewingTraining_movie.m**: Parameters file. There's a few important parameters to know about:
    - **cclab.moviespertype**: This determines the total number of movies that will be shown in the session. There will be cclab.moviespertype movies shown from each of nature, socially directed, and socially not-directed videos, so the total number of movies is 3 * cclab.moviespertype
    - **cclab.filepath**: Set in `paths.cfg` (copy from `paths.cfg.template`). Must point to the `video_ebm_dataset/` folder, which must contain subfolders: `video_all/`, `video_nature/`, `video_social_directed/`, and `video_social_undir/`
  - **RUN_freeviewingTraining_movie.m**: Run this file to run the paradigm!
  - **pseudorandomization.m**: Code to randomize movie order while making sure that every block of three movies includes one movie from each type. This code is called within the RUN_freeviewingTraining_movie.m file.
    - *This function will need to be modified if we also want to play boundary videos!*

Other stuff:

- **Pilot data**: Eye-tracking data from initial behavioral experiment with Vennie (now in `Data/Pilot data/`)
- **video_boundary** and **video_clipped**: Attempts at using online software to clip and combine videos to create some boundary videos (I was thinking it would be easiest to have a folder of boundary videos just like there's a folder of nature videos, socially directed videos, etc., rather than creating boundary videos by stitching together different videos on the fly within the code- that way the boundary videos can be run in exactly the same way as all the other videos.)
