function cclab = CONFI_exp01_transitions()
% CONFI_exp01_transitions
%
% Config for exp_01: free viewing across video transitions.
% Same shape as CONFI_freeviewingTraining_movie — copy a machine case from
% there if you add a rig.

%% Machine / rig identity
cclab.computer_name = 'dev_wsl';

% Where the videos are read from:
%   'nas'   — straight off the NAS share. No copying, always current, but a
%             cold read over the VPN runs at roughly 430 KB/s, which is far
%             too slow to stream a movie. Fine on the lab LAN.
%   'local' — a local copy of video_ebm_dataset/ (pull it once; see
%             docs/PICKUP.md). Use this off-site, and on any rig where a NAS
%             hiccup would drop frames. Convention: C:\cclab_data\ — off the
%             Desktop so OneDrive never tries to sync 5.5 GB, outside the repo,
%             and laid out exactly like the NAS share.
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

%% Seeding for Randomization
cclab.useFixedSeed = false;
cclab.randomSeed   = 1;

%% ---------------- exp_01 design ----------------
% 'transitions' — clips played back to back in a de Bruijn order, so every
%                 ordered category pair (N->N, N->D, ... U->U) occurs equally
%                 often. The cut is the event of interest.
% 'interleave'  — two clips alternate every segDur seconds for the whole trial
%                 (A B A B ...). Equalizes total exposure to both clips within
%                 a trial, so a difference cannot be blamed on one clip landing
%                 at a better moment. Many transitions per trial.
cclab.mode = 'transitions';

% Length of one clip drawn from a parent video (s).
% Sources are 30 s; durations.csv confirms 592/600 are 30.0 s.
cclab.clipDur = 10;

% Clips per trial in 'transitions' mode. The de Bruijn cycle continues across
% trial boundaries; the first segment of each trial is marked TransitionType
% "trial_start" and should be dropped from transition analyses.
cclab.clipsPerTrial = 3;

% 'interleave' mode: alternation period, and total screen time per clip.
% 2.5 s x 8 segments = 20 s trial, 10 s per clip.
cclab.interleaveSegDur   = 2.5;
cclab.interleaveClipTotal = 10;

% Number of passes through the condition set. One pass in 'transitions' mode
% is a 9-clip de Bruijn cycle; in 'interleave' mode it is the 9 ordered pairs.
cclab.nCycles = 2;

% Restrict to the hand-vetted subset flagged pilot_ready=1 in MANIFEST.csv.
cclab.pilot = true;

%% Timing (seconds)
cclab.durations.t_waitfixation_fp = 5;   % max time to acquire fixation
cclab.durations.t_fixation_fp     = 0.8; % hold time at trial start
cclab.durations.t_trialend        = 1.5; % ITI
cclab.durations.t_reward          = 1;   % reward image on screen

% Fixation BETWEEN segments.
%   > 0  fixation dot for this long at every cut. Re-zeroes gaze so the first
%        post-cut saccade is not confounded by wherever the eye ended up.
%   <= 0 (use 0 or -1) no fixation; fully continuous stream.
% Both are worth piloting — the dot cleans up the saccade measure but breaks
% the continuity that makes the cut a naturalistic event.
cclab.durations.t_fix_between = 0.5;

% Max time to re-acquire fixation at a between-segment dot before aborting.
cclab.durations.t_waitfix_between = 2;

%% Fixation / Window / Reward
cclab.windowSize = 3;      % acceptance window half-width (deg)
cclab.fpr        = 0.5;    % fixation dot radius (deg)
cclab.fp_x       = 0;
cclab.fp_y       = 0;
cclab.fp_color   = [0 0 0];

cclab.reward     = 600;    % ms
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
