function cclab = CONFI_freeviewingTraining_movie()
% CONFI_fixationTraining
%
% Returns a struct 'cclab' containing configuration parameters
% for a freeviewing training experiment.

%% Basic Info
% 0 => real EyeLink tracking 
% 1 => dummy mode using mouse input
cclab.dummymode      = 1;

%% Seeding for Randomization
% Set to true to use the fixed seed below, ensuring the same 
% "random" image sequence is generated every time.
cclab.useFixedSeed = false; 
% The specific seed for the random number generator.
cclab.randomSeed   = 1; % 1 for Vennie

%% Filepath
% The folder below must contain the subfolders 'Videos', 'Nature_videos',
% 'Social_directed_videos', and 'Social_notdirected_videos'
cclab.filepath = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos';

%% Block size
cclab.practiceBlockSize = 0; % Number of practice trials (I always had this set to 0, not sure if movie code will work if it's set to something else)
cclab.moviespertype = 2;     % Number of movies from each type (nature, social directed, social not directed)
%cclab.blocksize  = 10;      % Number of main experiment trials (this is not used for movie paradigm)
%cclab.numinarow = 3;        % Maximal number of movies from one type that can be played in a row (this ended up being unused)

%% Timing (seconds)
% Maximum time allowed to acquire fixation on the fixation point
cclab.durations.t_waitfixation_fp = 5;

% Time the subject must hold fixation
cclab.durations.t_fixation_fp = 0.8;

% Duration for the fixation dot to stay on the image
cclab.durations.t_fixdot_on_image = 0.8;

% Freeviewing duration on the image
cclab.durations.t_freeview = 5;

% Inter-trial interval duration (pause between trials)
cclab.durations.t_trialend = 1.5;

% How long to display the reward image after a successful trial
cclab.durations.t_reward = 1;

%% Fixation / Window / Reward
% Size of the acceptance window around the fixation point, in deg (half-width)
cclab.windowSize = 3;
% Radius of the fixation dot (deg)
cclab.fpr        = 0.5;
% (X,Y) offset of fixation point (deg)
cclab.fp_x       = 0;
cclab.fp_y       = 0;
% RGB color of the fixation dot (e.g., [255 0 0] for red, [0 0 0] for black, etc.)
cclab.fp_color   = [0 0 0];

% Base reward duration in milliseconds (juice delivery)
cclab.reward     = 600; % ms
% Whether to randomly double the reward
cclab.randreward = false;
% Probability threshold for doubling the reward (80% in this example)
cclab.randper    = 0.8;

%% Screen / PTB
% The display index that Psychtoolbox will use (0 usually the main display)
cclab.ScreenNumber  = 0;
% [width height] in pixels of the display window (set [0 0] for full screen)
cclab.screenSize    = [1080 720];
% Whether to skip PTB sync tests (0 = normal, 1 = skip; skip can reduce timing accuracy)
cclab.SkipSyncTests = 0;

% Viewing distance from the monkey's eyes to the screen (cm)
cclab.obs_dist     = 80;
% Physical width (cm) of the screen
cclab.screenWidth  = 60;

%% Rig / Reward Image
%addpath(fullfile(fileparts(pwd), 'cclab-matlab-tools')) % commented out SN
%2/13

% Which rig is being used ('Isaac', 'Wennie', etc.) — determines which reward image is loaded
cclab.whichMonkey         = 'Isaac';
% Path where reward images are stored
cclab.rewardImagePath  = pwd;
% Choose which reward image file to load based on 'whichMonkey'
switch lower(cclab.whichMonkey)
    case 'isaac'
        cclab.rewardImageFile = 'isaac_reward.png';
    case 'wennie'
        cclab.rewardImageFile = 'wennie_reward.png';
    otherwise
        cclab.rewardImageFile = 'isaac_reward.png';
end

% The size (in deg of visual angle) of the drawn reward image on the screen
cclab.rewardImageDimDeg = 6;
end
