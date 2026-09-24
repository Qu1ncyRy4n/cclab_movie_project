function cclab = CONFI_exp00_pilot()
% CONFI_exp00_pilot
%
% Config for exp_00: the deliberately tiny pilot. Two categories
% (nature, social_undir), 2 videos each, hand-picked from MANIFEST's
% pilot_ready column. No de Bruijn balancing, no MANIFEST-wide pooling —
% see Code/exp00_pilot_interleave/README.md for why.
%
% Same shape as CONFI_exp01_transitions — copy a machine case from there
% if you add a rig.

%% Machine / rig identity
cclab.computer_name = 'dev_wsl';

% Where the videos are read from — same semantics as exp01, see its CONFI
% for the tradeoffs. Only 4 files needed here, so 'nas' is fine even over
% the VPN (nothing like the 5.5 GB full-dataset case).
cclab.video_source = 'nas';

switch cclab.computer_name
    case {'lab_120', 'lab_121'}
        cclab.dummymode  = 0;
        cclab.filepath_nas   = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset';
        cclab.filepath_local = 'C:\cclab_data\video_ebm_dataset';
        cclab.matlab_path = 'C:\Users\cclab\Desktop\cclab_movie_project\Code';
        cclab.ScreenNumber = 2;
        cclab.screenSize   = [0 0];
    case 'q_mb_pro'
        cclab.dummymode  = 1;
        cclab.filepath_nas   = '/Volumes/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset';
        cclab.filepath_local = fullfile(getenv('HOME'), 'data', 'video_ebm_dataset');
        cclab.matlab_path = '/Users/username/Documents/MATLAB/cclab_movie_project/Code';
        cclab.ScreenNumber = 0;
        cclab.screenSize   = [1080 720];
    case 'dev_wsl'
        cclab.dummymode  = 1;
        cclab.filepath_nas   = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_ebm_dataset';
        cclab.filepath_local = 'C:\cclab_data\video_ebm_dataset';
        cclab.matlab_path = 'Q:\home\qix\dev\cclab_movie_project\Code';
        cclab.ScreenNumber = 0;
        cclab.screenSize   = [1080 720];
    otherwise
        error('CONFI: unknown computer_name "%s" — add a case to the switch block.', cclab.computer_name);
end

switch lower(cclab.video_source)
    case 'nas',   cclab.filepath = cclab.filepath_nas;
    case 'local', cclab.filepath = cclab.filepath_local;
    otherwise
        error('CONFI: video_source must be ''nas'' or ''local'', got "%s".', cclab.video_source);
end

if ~exist(fullfile(cclab.filepath, 'video_all'), 'dir')
    error('CONFI:noVideos', ...
        ['video_all/ not found under\n  %s\n(video_source = ''%s'')\n' ...
         'Check the share is mounted, or switch video_source.'], ...
        cclab.filepath, cclab.video_source);
end

% The 4-video pool itself — filename, category, duration_s. Resolved
% relative to this script file so it works regardless of MATLAB's cwd.
here = fileparts(mfilename('fullpath'));                     % Code/exp00_pilot_interleave
cclab.poolFile = fullfile(here, '..', '..', 'video_ebm_dataset', 'pilot_pool.csv');

%% Seeding
cclab.useFixedSeed = false;
cclab.randomSeed   = 1;

%% ---------------- exp_00 design ----------------
% Length of one interleaved chunk (s). 2 or 3 — both are worth trying;
% this is exploratory, not a settled parameter.
cclab.segDur = 2;

% Total seconds of each clip used per trial. Every pool video is >=7s
% (video_ebm_dataset/durations.csv), so 6s is always available with margin
% regardless of which 2 get drawn — no need for a min(A,B) trial-length
% rule like exp_01's. Must divide evenly by segDur.
cclab.perClipSeconds = 6;

if mod(cclab.perClipSeconds, cclab.segDur) ~= 0
    error('CONFI: perClipSeconds (%g) must be a whole multiple of segDur (%g).', ...
        cclab.perClipSeconds, cclab.segDur);
end
cclab.segsPerClip = cclab.perClipSeconds / cclab.segDur;

% Number of trials in the session.
cclab.nTrials = 40;

%% Timing (seconds)
cclab.durations.t_waitfixation_fp = 5;    % max time to acquire fixation
cclab.durations.t_fixation_fp     = 0.85; % required hold before interleave starts
cclab.durations.t_trialend        = 2;    % ITI (blank). 2 or 3 — exploratory, see segDur.
cclab.durations.t_reward          = 1;    % reward image on screen

%% Fixation / Window / Reward
cclab.windowSize = 3;      % acceptance window half-width (deg)
cclab.fpr        = 0.5;    % fixation dot radius (deg)
cclab.fp_x       = 0;
cclab.fp_y       = 0;
cclab.fp_color   = [0 0 0];

cclab.reward     = 600;    % ms, unconditional on completing the interleave
cclab.randreward = false;
cclab.randper    = 0.8;

%% Screen / PTB
cclab.SkipSyncTests = cclab.dummymode;
cclab.obs_dist      = 80;  % cm
cclab.screenWidth   = 60;  % cm

%% Rig / Reward Image
addpath(genpath(cclab.matlab_path));

cclab.whichMonkey     = 'Isaac';
cclab.rewardImagePath = fileparts(fileparts(mfilename('fullpath'))); % Code/
switch lower(cclab.whichMonkey)
    case 'isaac',  cclab.rewardImageFile = 'isaac_reward.png';
    case 'wennie', cclab.rewardImageFile = 'wennie_reward.png';
    otherwise,     cclab.rewardImageFile = 'isaac_reward.png';
end
cclab.rewardImageDimDeg = 6;
end
