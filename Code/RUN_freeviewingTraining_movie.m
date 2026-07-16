function RUN_freeviewingTraining_movie()
% RUN_freeviewingTraining
%
% After the monkey holds fixation, we present an image (free viewing) before delivering the reward.

clear all
close all

useRealEyelink = false;  % ponytail: default so the catch handler can't crash before line 109 sets it

try
    %% 1) Load config
    cclab = CONFI_freeviewingTraining_movie();

    % Seed the random number generator for reproducibility
    if cclab.useFixedSeed
        rng(cclab.randomSeed);
        fprintf('--- Using FIXED random seed: %d ---\n', cclab.randomSeed);
    else
        rng('shuffle'); % Seeds based on the current time for a new sequence
        fprintf('--- Using SHUFFLED (new) random seed ---\n');
    end

    % Open dialog box for EyeLink Data file name entry. File name up to 8 characters
    prompt = {'Enter subID file name (up to 8 characters)'};
    dlg_title = 'Create subID file';
    def = {'demo'}; % Create a default edf file name
    answer = inputdlg(prompt, dlg_title, 1, def); % Prompt for new EDF file name
    % Print some text in Matlab's Command Window if a file name has not been entered
    if  isempty(answer)
        fprintf('Session cancelled by user\n')
        error('Session cancelled by user'); % Abort experiment (see cleanup function below)
    end
    subID = answer{1}; % Save file name to a variable
    % Print some text in Matlab's Command Window if file name is longer than 8 characters
    if length(subID) > 8
        fprintf('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)\n');
        error('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)');
    end

    % Extract commonly used variables
    dummymode_EYE = cclab.dummymode;
    screenSize    = cclab.screenSize;
    screenNumber  = cclab.ScreenNumber;
    SkipSync      = cclab.SkipSyncTests;

    % Timings
    t_waitfix = cclab.durations.t_waitfixation_fp;
    t_holdfix = cclab.durations.t_fixation_fp;
    t_ITI     = cclab.durations.t_trialend;
    t_reward  = cclab.durations.t_reward;
    t_fixdot_on_image = cclab.durations.t_fixdot_on_image;
    %t_freeview = cclab.durations.t_freeview;

    % Fixation geometry
    fp_x_deg   = cclab.fp_x;
    fp_y_deg   = cclab.fp_y;
    fp_radius_deg = cclab.fpr;
    fixWindow_deg = cclab.windowSize;
    fixColor = cclab.fp_color;

    % Reward logic
    baseReward  = cclab.reward;
    randReward  = cclab.randreward;
    randPer     = cclab.randper;

    % Trials needed, skip logic
    %blockSize   = cclab.blocksize;

    % Define colors
    white = [255 255 255];
    grey = white / 2;
    black = [0 0 0];

    %% 2) Initialize PTB
    Screen('Preference', 'SkipSyncTests', SkipSync);
    KbName('UnifyKeyNames');

    % Basic key definitions
    escKey    = KbName('ESCAPE');
    pauseKey  = KbName('PageUp');
    unpauseKey= KbName('PageDown');
    %     rewardKey = KbName('space');
    %     calKey    = KbName('e');

    %% 3) Setup screen
    % sets the depth (in bits) of each pixel
    pixelSize = Screen('PixelSize', screenNumber);
    % Setting anything else than 2 will be only useful for debugging
    numBuffers = 2;

    if sum(screenSize) == 0
        [window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [], pixelSize, numBuffers, [], []);
    else
        [window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [0 0 screenSize(1) screenSize(2)], pixelSize, numBuffers, [], []);
    end
    [centerX, centerY] = RectCenter(windowRect);
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);

    % Compute pixels per degree
    ppcm    = screenXpixels / cclab.screenWidth;  % pixels per cm
    obs_dist= cclab.obs_dist; % viewing distance in cm
    ppd     = 2 * obs_dist * ppcm * tan(pi/360);

    fp_x_px   = round(fp_x_deg * ppd);
    fp_y_px   = round(fp_y_deg * ppd);
    fixRad_px = round(fp_radius_deg * ppd);
    fixWin_px = round(fixWindow_deg * ppd);

    %% 5) Initialize reward pump (only if not dummy)
    useRealEyelink = (dummymode_EYE == 0);
    if useRealEyelink
        cclabInitDIO('jA');
    end

    % HideCursor(screenNumber);
    % ListenChar(-1);

    %% 6) Load the Monkey-specific reward image (for the reward state)
    rewardImgPath = fullfile(cclab.rewardImagePath, cclab.rewardImageFile);
    if ~exist(rewardImgPath,'file')
        warning('Reward image file does not exist: %s', rewardImgPath);
        rewardImg = []; % fallback
    else
        rewardImg = imread(rewardImgPath);
        rewardImg(rewardImg == 0) = 127;
    end

    rewardImgDeg = cclab.rewardImageDimDeg;
    rewardImgPix = round(ppd * rewardImgDeg);
    baseRect = [0 0 rewardImgPix rewardImgPix];
    dstRectReward = CenterRectOnPointd(baseRect, centerX, centerY);

    %% 7) Load the movies for free viewing
    % --- Part 1: Load and shuffle PRACTICE images --- -- NOTE: Other than changing line 134, I actually didn't use 
    % practice movies at all when coding up the movie-watching paradigm (SN 3/19/26)
    %practiceMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\video_all'; % TO DO- add practice movies?
    practiceMovieDir = fullfile(cclab.filepath, 'video_all');
    %practiceImageDir = fullfile(pwd, 'images', 'practice');
    if ~exist(practiceMovieDir, 'dir') && cclab.practiceBlockSize > 0 
        error('Practice movie directory not found: %s', practiceMovieDir);
    end
    practiceMpgFiles = dir(fullfile(practiceMovieDir,'*.mpg'));
    allPracticeMovies = [practiceMpgFiles];
    numPracticeAvailable = numel(practiceMpgFiles);

    % Ensure we don't request more practice movies than available
    practiceBlockSize = cclab.practiceBlockSize;
    if practiceBlockSize > numPracticeAvailable
        warning('Requested %d practice images, but only %d are available. Using all.', ...
            practiceBlockSize, numPracticeAvailable);
        practiceBlockSize = numPracticeAvailable;
    end

    % Randomly select and then shuffle the practice movies
    practiceIdx = randperm(numPracticeAvailable, practiceBlockSize);
    shuffledPracticeFiles = allPracticeMovies(practiceIdx);

    % --- Part 2: Load and shuffle MAIN movies ---
    shuffledMainFiles = pseudorandomization(cclab.moviespertype, cclab.filepath);
    mainBlockSize = length(shuffledMainFiles);
    %mainBlockSize = 3*cclab.moviespertype; % 3 types of movies, nature/social directed/social not directed

    %mainMovieDir = '\\cns-nas.ucdavis.edu\cclab\shared\Bliss-Moreau_Machado_Videos\Videos'; 
    %if ~exist(mainMovieDir, 'dir')
    %    error('Main image directory not found: %s', mainMovieDir);
    %end
    %mainMpgFiles = dir(fullfile(mainMovieDir,'*.mpg'));
    %allMainMovies = [mainMpgFiles];
    %numMainAvailable = numel(mainMpgFiles);

    % Ensure we don't request more main movies than available
    %mainBlockSize = cclab.blocksize;
    %if mainBlockSize > numMainAvailable
    %    warning('Requested %d main movies, but only %d are available. Using all.', ...
    %        mainBlockSize, numMainAvailable);
    %    mainBlockSize = numMainAvailable;
    %end

    % Randomly select and then shuffle the main experiment images
    %mainIdx = randperm(numMainAvailable, mainBlockSize);
    %shuffledMainFiles = allMainMovies(mainIdx);

    % --- Part 3: Combine lists and pre-load all textures ---
    fprintf('Loading %d practice trials and %d main trials.\n', practiceBlockSize, mainBlockSize);
    selectedFiles = [shuffledPracticeFiles; shuffledMainFiles]; % Append main trials after practice
    totalSessionSize = numel(selectedFiles);
    playOrder = 1:totalSessionSize; % We play them in the already shuffled order
    currentPtr = 1;

    % Pre-load textures and destination rects for the entire session
    movieTextures = cell(totalSessionSize,1);
    movieDstRects = cell(totalSessionSize,1);

    for i = 1:totalSessionSize
        % Determine the correct source folder for the current movie
        if i <= practiceBlockSize
            movieFolder = practiceMovieDir;
            fname = fullfile(movieFolder, selectedFiles(i).name);
        else
            % Use the source folder recorded by dir() in pseudorandomization
            fname = fullfile(selectedFiles(i).folder, selectedFiles(i).name);
        end
        %tmpImg = imread(fname);
        %[imgH, imgW, ~] = size(tmpImg);

        %movieTextures{i} = Screen('MakeTexture', window, tmpImg);
        %fname
        %window
        %[movie, movieduration, fps, imgW, imgH, ~, ~, hdrStaticMetaData] = Screen('OpenMovie', window, fname);
        [movie, ~, ~, imgW, imgH, ~, ~, ~] = Screen('OpenMovie', window, fname, 4);
        movieTextures{i} = movie;

        scaleFactor = screenYpixels / imgH;
        newWidth  = round(imgW * scaleFactor);
        newHeight = round(imgH * scaleFactor);

        leftX   = (screenXpixels - newWidth) / 2;
        topY    = 0;
        rightX  = leftX + newWidth;
        bottomY = topY  + newHeight;
        movieDstRects{i} = [leftX, topY, rightX, bottomY];
    end

    %% 4) Setup EyeLink or dummy
    if useRealEyelink
        Eyelink('ShutDown');
        if ~EyelinkInit()
            warning('Could not init EyeLink. Forcing dummy mode...');
            useRealEyelink = false;
        end
    end

    if useRealEyelink
        edfFile = [subID];
        % Print some text in Matlab's Command Window if file name is longer than 8 characters
        if length(edfFile) > 8
            fprintf('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)\n');
            cleanup; % Abort experiment (see cleanup function below)
            return
        end

        % Open EDF file
        if Eyelink('OpenFile', edfFile) ~= 0
            fprintf('Cannot create EDF file %s', edfFile);
            cleanup;
            return
        end

        % Get EyeLink tracker and software version
        % <ver> returns 0 if not connected
        % <versionstring> returns 'EYELINK I', 'EYELINK II x.xx', 'EYELINK CL x.xx' where 'x.xx' is the software version
        [ver, versionstring] = Eyelink('GetTrackerVersion');
        % Extract software version number.
        [~, vnumcell] = regexp(versionstring,'.*?(\d)\.\d*?','Match','Tokens'); % Extract EL version before decimal point
        ELsoftwareVersion = str2double(vnumcell{1}{1}); % Returns 1 for EyeLink I, 2 for EyeLink II, 3/4 for EyeLink 1K, 5 for EyeLink 1KPlus, 6 for Portable Duo
        % Print some text in Matlab's Command Window
        fprintf('Running experiment on %s version %d\n', versionstring, ver );

        % This script calls Psychtoolbox commands available only in OpenGL-based
        % versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
        % only OpenGL-base Psychtoolbox.)  The Psychtoolbox command AssertPsychOpenGL will issue
        % an error message if someone tries to execute this script on a computer without
        % an OpenGL Psychtoolbox
        AssertOpenGL;

        % Select which events are saved in the EDF file. Include everything just in case
        Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        % Select which events are available online for gaze-contingent experiments. Include everything just in case
        Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
        % Select which sample data is saved in EDF file or available online. Include everything just in case
        if ELsoftwareVersion > 3  % Check tracker version and include 'HTARGET' to save head target sticker data for supported eye trackers
            Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
            Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
        else
            Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,GAZERES,BUTTON,STATUS,INPUT');
            Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
        end

        % Provide EyeLink with some defaults, which are returned in the structure "el".
        el = EyelinkInitDefaults(window);
        % set calibration/validation/drift-check(or drift-correct) size as well as background and target colors.
        % It is important that this background colour is similar to that of the stimuli to prevent large luminance-based
        % pupil size changes (which can cause a drift in the eye movement data)
        % 2) Find the smaller dimension of your screen:
        scrDim = min(screenXpixels, screenYpixels);
        % 3) Convert that diameter to a percentage for EyeLink:
        calibSizePercent = 100 * (fixRad_px / scrDim);
        el.calibrationtargetsize = calibSizePercent; % Outer target size as percentage of the screen
        el.calibrationtargetwidth = 0; % Inner target size as percentage of the screen
        el.backgroundcolour = grey; % RGB grey
        el.calibrationtargetcolour = fixColor; % RGB black
        % set "Camera Setup" instructions text colour so it is different from background colour
        el.msgfontcolour = black; % RGB black

        % Set calibration beeps (0 = sound off, 1 = sound on)
        el.targetbeep = 0;  % sound a beep when a target is presented
        el.feedbackbeep = 0;  % sound a beep after calibration or drift check/correction

        % You must call this function to apply the changes made to the el structure above
        EyelinkUpdateDefaults(el);

        % Set display coordinates for EyeLink data by entering left, top, right and bottom coordinates in screen pixels
        Eyelink('Command', 'screen_pixel_coords = 0 0 %d %d', screenXpixels-1, screenYpixels-1);
        % Write DISPLAY_COORDS message to EDF file: sets display coordinates in DataViewer
        % See DataViewer manual section: Protocol for EyeLink Data to Viewer Integration > Pre-trial Message Commands
        Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, screenXpixels-1, screenYpixels-1);
        % Set number of calibration/validation dots and spread: horizontal-only(H) or horizontal-vertical(HV) as H3, HV3, HV5, HV9 or HV13
        Eyelink('Command', 'calibration_type = HV9'); % horizontal-vertical 9-points
        % Allow a supported EyeLink Host PC button box to accept calibration or drift-check/correction targets via button 5
        Eyelink('Command', 'button_function 5 "accept_target_fixation"');
        % Clear Host PC display from any previus drawing
        Eyelink('Command', 'clear_screen 0');

        % Put EyeLink Host PC in Camera Setup mode for participant setup/calibration
        EyelinkDoTrackerSetup(el);
        WaitSecs(0.1);

    else
        fprintf('Running in dummy/mouse mode.\n');
    end

    %% -----------------------------------------------------------------
    %% 8)  Results table  (latencies / times are in **ms** relative to trial start)
    % Save dir
    outFolder = fullfile(pwd, 'Output_freeviewingTraining', [subID '_' datestr(now,'yyyy-mm-dd_HHMM')]);
    if ~exist(outFolder, 'dir'), mkdir(outFolder); end
    outMat = fullfile(outFolder, [subID '_' datestr(now,'yyyy-mm-dd_HHMM') '.mat']);

    Results = table( ...
        'Size',[0 12], ... 
        'VariableTypes',{'double','string','double','double','string', 'cell', 'double','double','double','double','double','string'}, ...
        'VariableNames',{'TrialNum','TrialType','TrialSuccess','RewardSize','ImageShown','ImageRect' ...
        'TrialStart','FixStart','FixEnd','ImageOn','DotOff','AbortPhase'});

    total_success = 0;
    total_trials  = 0;
    break_out     = false;

    state = "Trial_start";
    trial_start_time = GetSecs;

    %% Eyelink
    if useRealEyelink
        % Start recording
        Eyelink('SetOfflineMode'); % Put tracker in idle/offline mode before recording
        Eyelink('StartRecording'); % Start tracker recording
        WaitSecs(0.1); % Allow some time to record a few samples before presenting first stimulus
        % Check which eye is available. Returns 0 (left), 1 (right) or 2 (binocular)
        eyeUsed = Eyelink('EyeAvailable');
        % Get samples from right eye if binocular
        if eyeUsed == 2
            eyeUsed = 1;
        end
        % Perform drift correction
        Eyelink('Command', 'drift_correct_cr_disable = OFF');
        Eyelink('Command', 'online_dcorr_refposn %i,%i', centerX, centerY);
    else
        eyeUsed = NaN;
    end

    while ~break_out

        % ---------- experimenter keys ----------
        [~, ~, keyCode] = KbCheck;
        if keyCode(escKey)
            fprintf('ESC pressed, quitting.\n');  state = "Exp_end";
        elseif keyCode(pauseKey)
            state = "Pause";
            %         elseif keyCode(rewardKey) && useRealEyelink
            %             cclabReward(baseReward,1,1000);
            %         elseif keyCode(calKey)
            %             %--------------------------------------------------------
            %             % 'e' key: Pause and open Eyelink calibration
            %             %--------------------------------------------------------
            %             if useRealEyelink
            %                 fprintf('Opening Eyelink Calibration...\n');
            %                 EyelinkDoTrackerSetup(el);
            %                 WaitSecs(0.1);
            %                 Eyelink('StartRecording');
            %                 WaitSecs(0.1);
            %                 fprintf('Calibration finished; resuming.\n');
            %             end
        end

        if useRealEyelink

            % Check that eye tracker is  still recording. Otherwise close and transfer copy of EDF file to Display PC
            err = Eyelink('CheckRecording');
            if(err ~= 0)
                fprintf('EyeLink Recording stopped!\n');
                % Transfer a copy of the EDF file to Display PC
                Eyelink('SetOfflineMode'); % Put tracker in idle/offline mode
                Eyelink('CloseFile'); % Close EDF file on Host PC
                Eyelink('Command', 'clear_screen 0'); % Clear trial image on Host PC at the end of the experiment
                WaitSecs(0.1); % Allow some time for screen drawing
                % Receive the file
                newFileName = [subID '_' datestr(now,'yyyy-mm-dd_HHMM') '_edf'];
                status = Eyelink('ReceiveFile', edfFile, fullfile(outFolder, newFileName), 1);
                if status == 0
                    fprintf('File received and saved as %s\n', fullfile(outFolder, newFileName));
                else
                    fprintf('Error receiving file.\n');
                end
                Eyelink('ShutDown');
                cleanup; % Abort experiment
                return
            end
        end

        switch state
            % -----------------------------------------------------------------
            case "Trial_start"
                total_trials = total_trials + 1;
                fprintf('\n=== Trial #%d (success so far=%d) ===\n', ...
                    total_trials, total_success);

                % Determine if the current trial is practice or main
                if total_trials <= practiceBlockSize
                    currentTrialType = "Practice";
                else
                    currentTrialType = "Main";
                end

                % create per‑trial struct (all latencies initialised as NaN)
                trialInfo = struct( ...
                    'TrialNum'    , total_trials, ...
                    'TrialType'   , currentTrialType, ... 
                    'TrialSuccess', 0, ...
                    'RewardSize'  , 0, ...
                    'ImageShown'  ,"", ...
                    'ImageRect'   , {[]}, ...
                    'TrialStart'  , 0, ...
                    'FixStart'    , NaN, ...
                    'FixEnd'     , NaN, ...
                    'ImageOn'     , NaN, ...
                    'DotOff'      , NaN, ...
                    'AbortPhase'  ,"None");

                if useRealEyelink
                    Eyelink('Message','TrialStart_%d',total_trials);
                end

                % draw fixation
                Screen('FillRect',window,[128 128 128]);
                Screen('FillOval',window,fixColor, ...
                    [centerX+fp_x_px-fixRad_px, centerY-fp_y_px-fixRad_px, ...
                    centerX+fp_x_px+fixRad_px, centerY-fp_y_px+fixRad_px],8);
                Screen('Flip',window);

                %--------------------------------------------------------
                % Also draw the fixation window box on the Eyelink host
                %--------------------------------------------------------
                if useRealEyelink
                    % Clear the Host display, then draw the box in that space
                    Eyelink('command','clear_screen 0');

                    fixWin_left   = centerX + fp_x_px - fixWin_px/2;
                    fixWin_right  = centerX + fp_x_px + fixWin_px/2;
                    fixWin_top    = centerY - fp_y_px - fixWin_px/2;
                    fixWin_bottom = centerY - fp_y_px + fixWin_px/2;

                    % Format the command string with the coordinates
                    command = sprintf('draw_box %d %d %d %d 15', fixWin_left, fixWin_top, fixWin_right, fixWin_bottom);

                    % Send the command to Eyelink
                    Eyelink('Command', command);

                end

                trial_start_time = GetSecs;
                state = "Wait_for_fixation";

                % -----------------------------------------------------------------
            case "Wait_for_fixation"
                inFix = checkFixation(useRealEyelink,window,fp_x_px,fp_y_px, ...
                    fixWin_px,centerX,centerY,eyeUsed);

                if inFix
                    if useRealEyelink, Eyelink('Message','FixInFP_%d',total_trials); end
                    trial_start_time_hold = GetSecs;   % start timing the hold
                    trialInfo.FixStart = 1000*(trial_start_time_hold - trial_start_time); % ms
                    state = "Hold_fix";

                elseif (GetSecs - trial_start_time) > t_waitfix
                    fprintf('\tFailed to acquire fixation.\n');
                    trialInfo.AbortPhase = "Wait_for_fixation";
                    state = "ITI";
                end

                % -----------------------------------------------------------------
            case "Hold_fix"
                inFix = checkFixation(useRealEyelink,window,fp_x_px,fp_y_px, ...
                    fixWin_px,centerX,centerY,eyeUsed);

                if ~inFix
                    fprintf('\tBroke fixation.\n');
                    trialInfo.AbortPhase = "Hold_fix";
                    state = "ITI";

                elseif (GetSecs - trial_start_time_hold) >= t_holdfix
                    % fixation held long enough
                    %total_success = total_success + 1;
                    trialInfo.FixEnd = 1000*(GetSecs - trial_start_time);  % ms

                    idx              = playOrder(currentPtr);
                    chosenTex        = movieTextures{idx};
                    chosenImageName  = selectedFiles(idx).name;
                    dstRect = movieDstRects{idx};

                    trialInfo.ImageShown = chosenImageName;
                    trialInfo.ImageRect = movieDstRects(idx);

                    state = "Movie_present";
                end

                % -----------------------------------------------------------------
            case "Movie_present"
                trialInfo.ImageOn = 1000*(GetSecs - trial_start_time);  % ms
                if useRealEyelink
                    Eyelink('Message','ImageOn_%d', total_trials);
                end

                % image + dot, enforce fixation
                %t0 = GetSecs;
                %while (GetSecs - t0) < t_fixdot_on_image
                %    Screen('FillRect',window,[128 128 128]);
                %    Screen('DrawTexture',window,chosenTex,[],dstRect);
                %    Screen('FillOval',window,fixColor, ...
                %        [centerX+fp_x_px-fixRad_px, centerY-fp_y_px-fixRad_px, ...
                %        centerX+fp_x_px+fixRad_px, centerY-fp_y_px+fixRad_px],8);
                %    Screen('Flip',window);

                %    if ~checkFixation(useRealEyelink,window,fp_x_px,fp_y_px, ...
                %            fixWin_px,centerX,centerY,eyeUsed)
                %        fprintf('\tBroke fixation during image+dot.\n');
                %        trialInfo.AbortPhase = "ImageDot";
                %        state = "ITI";
                %        break
                %    end
                %end

                %if state == "Movie_present"
                
                %%% Playback loop to fetch video frames and display them %%%
                rate=1;
                Screen('PlayMovie', chosenTex, rate);

                % Play movie + show fixation dot
                t0 = GetSecs;
                while (GetSecs - t0) < t_fixdot_on_image
                    % Get next frame of movie and draw to screen
                    if ((abs(rate)>0) && (imgW>0) && (imgH>0) && (state == 'Movie_present'))
                        tex = Screen('GetMovieImage', window, chosenTex);
                        if tex < 0
                            break;
                        end
                        if tex == 0
                            WaitSecs('YieldSecs', 0.005);
                            continue;
                        end
        
                        % Draw fixation dot and the new movie texture immediately to screen:
                        Screen('DrawTexture', window, tex, [], dstRect);
                        Screen('FillOval',window,fixColor, ...
                            [centerX+fp_x_px-fixRad_px, centerY-fp_y_px-fixRad_px, ...
                            centerX+fp_x_px+fixRad_px, centerY-fp_y_px+fixRad_px],8);
                        Screen('Flip', window);
                        %Screen('Flip', window, [], [], 1);
                        Screen('Close', tex);
                    end

                    % Check for escape key
                    [~, ~, keyCode] = KbCheck;
                    if keyCode(escKey)
                        fprintf('ESC pressed, quitting.\n');  
                        state = "Exp_end";
                        break;
                    end

                    % Check for loss of fixation
                    if ~checkFixation(useRealEyelink,window,fp_x_px,fp_y_px, ...
                            fixWin_px,centerX,centerY,eyeUsed)
                        fprintf('\tBroke fixation during image+dot.\n');
                        trialInfo.AbortPhase = "ImageDot";
                        state = "ITI";
                        
                        % If fixation lost, stop playback but don't close up the movie pointer (chosenTex) yet
                        Screen('Flip', window);
                        KbReleaseWait;
                        Screen('PlayMovie', chosenTex, 0);
                        break
                    end
                end
                

                % If still in this state, fixation was held, continue playing movie
                if state == "Movie_present"
                    total_success = total_success + 1; % counting number of successful trials

                    % Record dot off
                    trialInfo.DotOff = 1000*(GetSecs - trial_start_time);  % ms
                    if useRealEyelink
                        Eyelink('Message','DotOff_%d', total_trials);
                    end

                    while 1
                        % Check for escape key:
                        [~, ~, keyCode] = KbCheck;
                        if keyCode(escKey)
                            fprintf('ESC pressed, quitting.\n');  
                            state = "Exp_end";
                            break;
                        end
                    
                        % Present the next video frame
                        if ((abs(rate)>0) && (imgW>0) && (imgH>0) && (state == 'Movie_present'))
                            tex = Screen('GetMovieImage', window, chosenTex);
                            if tex < 0
                                break;
                            end
                            if tex == 0
                                WaitSecs('YieldSecs', 0.005);
                                continue;
                            end
            
                            % Draw the new texture immediately to screen:
                            Screen('DrawTexture', window, tex, [], dstRect);
                            Screen('Flip', window, [], [], 1);
                            Screen('Close', tex);
                        end
                    end

                    % Close everything up
                    Screen('Flip', window);
                    KbReleaseWait;
                    Screen('PlayMovie', chosenTex, 0); % Stop playback
                    Screen('CloseMovie', chosenTex); % Close movie object
                end

                if state == "Movie_present"
                    state = "Reward";
                end
                %elseif state == "ITI"
                %    state = "ITI";
                %else
                %    state = "Exp_end";
                %end
                    
                %end
                

                % -----------------------------------------------------------------
            case "Reward"
                if useRealEyelink, Eyelink('Message','Reward_%d',total_trials); end

                Screen('FillRect',window,[128 128 128]);
                if ~isempty(rewardImg)
                    tex = Screen('MakeTexture',window,rewardImg);
                    Screen('DrawTexture',window,tex,[],dstRectReward);
                else
                    DrawFormattedText(window,'REWARD!','center','center',[0 255 0]);
                end
                Screen('Flip',window);

                rAmount = baseReward;
                if randReward && (rand()>randPer), rAmount = 2*baseReward; end
                if useRealEyelink, cclabReward(rAmount,1,1000); end
                WaitSecs(t_reward);

                trialInfo.TrialSuccess = 1;
                trialInfo.RewardSize   = rAmount;

                currentPtr = currentPtr + 1;

                state = "ITI";

                % -----------------------------------------------------------------
            case "ITI"
                Screen('FillRect',window,[128 128 128]);
                Screen('Flip',window);
                WaitSecs(t_ITI);

                % append results
                Results(end+1, :) = struct2table(trialInfo, 'AsArray', true);
                save(outMat, 'Results', 'cclab');

                % stop when the required number of rewarded trials is reached
                if total_success >= totalSessionSize
                    fprintf('Reached total trials = %d.\n', totalSessionSize);
                    state = "Exp_end";
                else
                    state = "Trial_start";
                end

                % -----------------------------------------------------------------
            case "Pause"
                DrawFormattedText(window,'PAUSED\n(Press PageDown (PgDn) to resume)', ...
                    'center','center',[255 255 0]);
                Screen('Flip',window);
                [~,~,keyPause] = KbCheck;
                if keyPause(unpauseKey), state = "Trial_start"; end

            case "Exp_end"
                break_out = true;
        end
    end

    %% Clean up EyeLink
    if useRealEyelink
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        Eyelink('ReceiveFile', edfFile, outFolder, 1);
        Eyelink('ShutDown');
    end

    %cleanup(window);   %ASK ORHAN ABOUT THIS?
    cleanup();

catch ME
    % This block runs if an error occurs or if the user stops the script.
    
    fprintf('\n!!! --- SCRIPT INTERRUPTED --- !!!\n');
    fprintf('An error occurred: %s\n', ME.message);
    fprintf('Attempting to save Eyelink data before exiting...\n\n');

    % Gracefully shut down EyeLink and transfer the data file
    if useRealEyelink
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        
        % Attempt to receive the file
        try
            fprintf('Receiving EDF file ''%s''...\n', edfFile);
            status = Eyelink('ReceiveFile', edfFile, outFolder, 1);
            if status > 0
                fprintf('EDF file successfully received and saved in:\n%s\n', outFolder);
            else
                fprintf('Warning: EDF file could not be received (Status: %d).\n', status);
            end
        catch receive_error
            fprintf('CRITICAL ERROR during Eyelink file reception: %s\n', receive_error.message);
        end
        
        % Shut down Eyelink connection
        Eyelink('ShutDown');
        fprintf('Eyelink shut down.\n');
    end
    
    % Run the original cleanup (closes screen, etc.)
    cleanup();
    
    % Rethrow the original error to notify the user of what went wrong
    rethrow(ME);
end
end


%% checkFixation: uses EyeLink or Mouse
function inFix = checkFixation(useRealEyelink, window, xFixPx, yFixPx, fixWinPx, centerX, centerY, eyeUsed)
inFix = false;
if useRealEyelink
    evt = Eyelink('NewestFloatSample');
    if isempty(evt), return; end

    % Select the correct eye's data using eyeUsed + 1
    % eyeUsed = 0 (left) -> index 1
    % eyeUsed = 1 (right) -> index 2
    eye_idx = eyeUsed + 1;
    ex  = evt.gx(eye_idx);
    ey  = evt.gy(eye_idx);
else
    [mx, my] = GetMouse(window);
    ex = mx;
    ey = my;
end
box_left   = centerX + xFixPx - fixWinPx/2;
box_right  = centerX + xFixPx + fixWinPx/2;
box_top    = centerY - yFixPx - fixWinPx/2;
box_bottom = centerY - yFixPx + fixWinPx/2;
if ex >= box_left && ex <= box_right && ey >= box_top && ey <= box_bottom
    inFix = true;
end
end

function cleanup()
if nargin>0
    Screen('CloseAll');
else
    sca;
end
% ShowCursor;
ListenChar(0);
Priority(0);
end

%% Orhan Soyuhos, 2025
% Modified by Shoshana Novik, 2026, for  the movie freeviewing task
