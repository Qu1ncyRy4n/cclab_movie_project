function cclab = CONFI_freeviewingTraining_movie()
% CONFI_fixationTraining
%
% Returns a struct 'cclab' containing configuration parameters
% for a freeviewing training experiment.

%% Basic Info
% 0 => real EyeLink tracking 
% 1 => dummy mode using mouse input
cclab.dummymode      = 0;
cclab.operating_system = "Windows11"; 

if cclab.dummymode == 1
    SkipSyncTests = 1;
    Screen('Preference', 'SkipSyncTests', 1);
end

%% Seeding for Randomization
% Set to true to use the fixed seed below, ensuring the same 
% "random" image sequence is generated every time.
cclab.useFixedSeed = false; 
% The specific seed for the random number generator.
cclab.randomSeed   = 1; % 1 for Vennie

%% Filepath
% video_path points to video_ebm_dataset/ and must contain video_all/.
% Set computer_name in paths.cfg (copy from paths.cfg.template, gitignored).
% CONFI reads paths.cfg → looks up video_path in the named section of paths.cfg.template.
repoRoot  = fullfile(fileparts(mfilename('fullpath')), '..');
pathsCfg  = fullfile(repoRoot, 'paths.cfg');
pathsTmpl = fullfile(repoRoot, 'paths.cfg.template');

cclab.filepath = '';
if exist(pathsCfg, 'file')
    computerName = cfgKey(pathsCfg, '', 'computer_name');
    if ~isempty(computerName) && exist(pathsTmpl, 'file')
        cclab.filepath = cfgKey(pathsTmpl, computerName, 'video_path');
    end
    if isempty(cclab.filepath)           % legacy: flat 'filepath' key in paths.cfg
        cclab.filepath = cfgKey(pathsCfg, '', 'filepath');
    end
end

if isempty(cclab.filepath)
    % OS defaults — create paths.cfg from paths.cfg.template to override
    if cclab.operating_system == "MacOS"
        cclab.filepath = '/Volumes/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset';
    elseif cclab.operating_system == "Linux"
        cclab.filepath = '/mnt/cclab/shared/Bliss-Moreau_Machado_Videos/video_ebm_dataset';
    else % Windows
        cclab.filepath = 'C:\Users\qmryan\Desktop\Bliss-Moreau_Machado_Videos\video_ebm_dataset';
    end
end

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
% Forced on in dummymode — sync tests fail on non-rig displays
cclab.SkipSyncTests = cclab.dummymode;

% Viewing distance from the monkey's eyes to the screen (cm)
cclab.obs_dist     = 80;
% Physical width (cm) of the screen
cclab.screenWidth  = 60;

%% Rig / Reward Image
addpath(fullfile(fileparts(mfilename('fullpath')), 'cclab-matlab-tools'))
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

% ---------------------------------------------------------------------------
function val = cfgKey(filename, section, key)
% Read key from an INI-style config. section='' reads global (pre-section) keys.
val = '';
fid = fopen(filename, 'r');
if fid < 0, return; end
inTarget = isempty(section);
while true
    line = fgetl(fid);
    if ~ischar(line), break; end
    line = strtrim(line);
    if isempty(line) || line(1) == '#' || line(1) == ';', continue; end
    if line(1) == '['
        br = find(line == ']', 1);
        if ~isempty(br)
            inTarget = strcmpi(strtrim(line(2:br-1)), section);
        end
        continue;
    end
    if ~inTarget, continue; end
    eq = find(line == '=', 1);
    if isempty(eq), continue; end
    if strcmpi(strtrim(line(1:eq-1)), key)
        val = strtrim(line(eq+1:end));
        break;
    end
end
fclose(fid);
end
