function cclab = CONFI_freeviewingTraining_movie()
% CONFI_fixationTraining
%
% Returns a struct 'cclab' containing configuration parameters
% for a freeviewing training experiment.

%% Machine / rig identity
% Set computer_name to match this machine. Everything else is derived from it.
% Lab rigs (lab_120, lab_121) get dummymode=0 (real EyeLink); all others dummymode=1 (mouse).
% To add a new machine: add a case with dummymode, filepath, and matlab_path.
%
% matlab_path — the Code/ folder of this repo on the local filesystem.
%   CONFI adds it (and cclab-matlab-tools inside it) to MATLAB's search path
%   automatically, so scripts are findable for the rest of the session.
%   Note: MATLAB must be able to find RUN_ or CONFI initially (e.g. cd Code/
%   once, or add Code/ to MATLAB's default path in Preferences).
cclab.computer_name = 'dev_wsl';

switch cclab.computer_name
    case {'lab_120', 'lab_121'}
        cclab.dummymode  = 0;
        cclab.filepath   = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset'; % file path requires video_all/ and MANIFEST.csv
        cclab.matlab_path = 'C:\Users\cclab\Desktop\cclab_movie_project\Code'; % rig Windows account is 'cclab', not a personal username
        % Screen 2 + fullscreen fixed a PTB VBL sync failure during pilot testing (2026-07-29).
        cclab.ScreenNumber = 2;
        cclab.screenSize   = [0 0];
    case 'q_mb_pro'
        cclab.dummymode  = 1;
        cclab.filepath   = '/Volumes/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset';
        cclab.matlab_path = '/Users/username/Documents/MATLAB/cclab_movie_project/Code';
        cclab.ScreenNumber = 0;
        cclab.screenSize   = [1080 720];
    case 'dev_wsl'
        cclab.dummymode  = 1;
        cclab.filepath   = 'C:\Users\qmryan\Desktop\Bliss-Moreau_Machado_Videos\video_ebm_dataset';
        cclab.matlab_path = 'Q:\home\qix\dev\cclab_movie_project\Code';
        cclab.ScreenNumber = 0;
        cclab.screenSize   = [1080 720];
    otherwise
        error('CONFI: unknown computer_name "%s" — add a case to the switch block.', cclab.computer_name);
end

%% Seeding for Randomization
% Set to true to use the fixed seed below, ensuring the same 
% "random" image sequence is generated every time.
cclab.useFixedSeed = false; 
% The specific seed for the random number generator.
cclab.randomSeed   = 1; % 1 for Vennie

%% Block size
cclab.practiceBlockSize = 0; % Number of practice trials (I always had this set to 0, not sure if movie code will work if it's set to something else)
cclab.moviespertype = 3;     % Number of movies from each type (nature, social directed, social not directed)

% Restrict movie selection to the hand-vetted subset flagged pilot_ready=1 in
% MANIFEST.csv. Set true during piloting; false for real data collection.
cclab.pilot = true;
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
% ScreenNumber and screenSize are set per-machine in the switch block above.
% Whether to skip PTB sync tests (0 = normal, 1 = skip; skip can reduce timing accuracy)
% Forced on in dummymode — sync tests fail on non-rig displays
cclab.SkipSyncTests = cclab.dummymode;

% Viewing distance from the monkey's eyes to the screen (cm)
cclab.obs_dist     = 80;
% Physical width (cm) of the screen
cclab.screenWidth  = 60;

%% Rig / Reward Image
addpath(cclab.matlab_path);
addpath(fullfile(cclab.matlab_path, 'cclab-matlab-tools'));

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
