This folder contains initial work on the movie project from my rotation!

## **What's in the Bliss-Moreau_Machado_Videos folder:**

Videos and code (all of these are needed to run the movie viewing paradigm):

- **Videos**: All the initial videos from the Bliss-Moreau_Machado dataset
- **Nature_videos**: The subset of videos that are of nature scenes
- **Socially_directed_videos**: The subset of videos that are of socially directed scenes
- **Socially_notdirected_videos**: The subset of videos that are of social non-directed scenes
- **Code**: All code needed to run the movie paradigm
  - **CONFI_freeviewingTraining_movie.m**: Parameters file. There's a few important parameters to know about:
    - **cclab.moviespertype**: This determines the total number of movies that will be shown in the session. There will be cclab.moviespertype movies shown from each of nature, socially directed, and socially not-directed videos, so the total number of movies is 3 * cclab.moviespertype
    - **cclab.filepath**: Currently, this is '\\\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos'. For the code to work, this filepath must contain the following subfolders: 'Videos', 'Nature_videos', 'Socially_directed_videos', and 'Socially_notdirected_videos'
  - **RUN_freeviewingTraining_movie.m**: Run this file to run the paradigm!
  - **pseudorandomization.m**: Code to randomize movie order while making sure that every block of three movies includes one movie from each type. This code is called within the RUN_freeviewingTraining_movie.m file.
    - *This function will need to be modified if we also want to play boundary videos!*

Other stuff:

- **Pilot data**: Eye-tracking data from initial behavioral experiment with Vennie
- **Boundary_videos** and **Clipped_videos**: My attempts at using online software to clip and combine videos to create some boundary videos (I was thinking it would be easiest to have a folder of boundary videos just like there's a folder of nature videos, socially directed videos, etc., rather than creating boundary videos by stitching together different videos on the fly within the code- that way the boundary videos can be run in exactly the same way as all the other videos.)
