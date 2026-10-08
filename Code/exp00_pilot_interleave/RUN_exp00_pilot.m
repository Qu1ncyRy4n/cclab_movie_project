function RUN_exp00_pilot(subID, sessionPlanFile)
% RUN_exp00_pilot
%
% exp_00: the deliberately tiny pilot. Per trial:
%   a. fixation dot, hold cclab.durations.t_fixation_fp (0.85s default)
%   b. pick 2 DISTINCT videos at random from the 4-video pool (pilot_pool.csv),
%      interleave them in place (A B A B ...) at cclab.segDur seconds each,
%      cclab.perClipSeconds of each clip total (from t=0, no random offset —
%      every pool video is >=7s so this is always safe with margin)
%   c. unconditional reward
%   d. ITI (blank, cclab.durations.t_trialend)
%   e. repeat until cclab.nTrials
%
% No de Bruijn balancing, no category-pair machinery, no buildSequence.m —
% deliberately simpler than exp_01. See README.md for why. Video selection
% happens live, trial by trial, not pre-planned, so "which pair got shown
% and how many times before" can be logged as it happens (TimesShownBeforeA/B
% columns) for future familiarity/repetition analysis — not used to steer
% selection yet, just recorded.
%
% Results has ONE ROW PER TRIAL. Per-segment onset/offset still goes to the
% EDF as SegOn_/SegOff_ messages, so segment-level timing is recoverable
% there if needed later.
%
% Adapted from RUN_exp01_transitions.m / RUN_freeviewingTraining_movie.m.

close all

useRealEyelink = false;
useNeuralIO = false;
dioInitialized = false;

try
    %% 1) Load config
    cclab = CONFI_exp00_pilot();

    if cclab.useFixedSeed
        rng(cclab.randomSeed);
        fprintf('--- Using FIXED random seed: %d ---\n', cclab.randomSeed);
    else
        rng('shuffle');
        fprintf('--- Using SHUFFLED (new) random seed ---\n');
    end

    if nargin < 1 || isempty(subID)
        fprintf('\nexp_00 startup (Command Window)\n');
        fprintf('Allowed participants: %s\n', strjoin(cclab.allowedParticipants, ', '));
        subID = input('Participant: ', 's');
    else
        subID = char(subID);
    end
    useSessionPlan = nargin >= 2 && ~isempty(sessionPlanFile);
    if useSessionPlan
        sessionPlanFile = char(sessionPlanFile);
        if ~exist(sessionPlanFile, 'file')
            error('exp00:missingPlan', 'Session plan not found: %s', sessionPlanFile);
        end
    end
    if ~any(strcmpi(subID, cclab.allowedParticipants))
        error('Participant must be one of: %s', strjoin(cclab.allowedParticipants, ', '));
    end
    if strlength(cclab.experimenter) == 0
        cclab.experimenter = string(strtrim(input('Experimenter/developer: ', 's')));
    end
    if strlength(cclab.experimenter) == 0
        error('Experimenter/developer name is required.');
    end
    fprintf('Participant: %s; experimenter/developer: %s\n', subID, cclab.experimenter);
    printOperatorControls();
    fprintf('Reward pump-on duration: %g ms (set CCLAB_REWARD_MS before launch to change it).\n\n', cclab.reward);

    dummymode_EYE = cclab.dummymode;
    screenSize    = cclab.screenSize;
    screenNumber  = cclab.ScreenNumber;
    SkipSync      = cclab.SkipSyncTests;

    t_holdfix = cclab.durations.t_fixation_fp;
    t_ITI     = cclab.durations.t_trialend;
    t_reward  = cclab.durations.t_reward;

    fp_x_deg      = cclab.fp_x;
    fp_y_deg      = cclab.fp_y;
    fp_radius_deg = cclab.fpr;
    fixWindow_deg = cclab.windowSize;
    fixColor      = cclab.fp_color;

    baseReward = cclab.reward;
    randReward = cclab.randreward;
    randPer    = cclab.randper;

    white = [255 255 255];
    grey  = white / 2;
    black = [0 0 0];

    %% 2) Initialize PTB
    Screen('Preference', 'SkipSyncTests', SkipSync);
    KbName('UnifyKeyNames');
    escKey     = KbName('ESCAPE');
    pauseKey   = KbName('UpArrow');
    unpauseKey = KbName('DownArrow');
    forcePauseKey = KbName('f');

    %% 3) Setup screen
    pixelSize  = Screen('PixelSize', screenNumber);
    numBuffers = 2;

    if sum(screenSize) == 0
        [window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [], pixelSize, numBuffers, [], []);
    else
        [window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey, [0 0 screenSize(1) screenSize(2)], pixelSize, numBuffers, [], []);
    end
    [centerX, centerY] = RectCenter(windowRect);
    [screenXpixels, screenYpixels] = Screen('WindowSize', window);

    ppcm     = screenXpixels / cclab.screenWidth;
    obs_dist = cclab.obs_dist;
    ppd      = 2 * obs_dist * ppcm * tan(pi/360);

    fp_x_px   = round(fp_x_deg * ppd);
    fp_y_px   = round(fp_y_deg * ppd);
    fixRad_px = round(fp_radius_deg * ppd);
    fixWin_px = round(fixWindow_deg * ppd);

    %% 4) Digital I/O (reward pump + TTL sync)
    useRealEyelink = cclab.useEyelink;
    useNeuralIO = cclab.useNeuralIO;
    fprintf('EyeLink enabled: %d; neural I/O enabled: %d\n', useRealEyelink, useNeuralIO);
    if useNeuralIO
        cclabInitDIO('rig-right');
        dioInitialized = true;
    end

    %% 5) Reward image
    rewardImgPath = fullfile(cclab.rewardImagePath, cclab.rewardImageFile);
    if ~exist(rewardImgPath, 'file')
        warning('Reward image file does not exist: %s', rewardImgPath);
        rewardImg = [];
    else
        rewardImg = imread(rewardImgPath);
        rewardImg(rewardImg == 0) = 127;
    end
    rewardImgPix  = round(ppd * cclab.rewardImageDimDeg);
    dstRectReward = CenterRectOnPointd([0 0 rewardImgPix rewardImgPix], centerX, centerY);

    %% 6) Load the pilot pool or a precomputed full-session plan
    if useSessionPlan
        sessionPlan = readtable(sessionPlanFile, 'TextType', 'string');
        requiredPlanColumns = {'Epoch','TrialInEpoch','TrialNum','Condition', ...
            'VideoA','VideoB','CategoryA','CategoryB','StartA_s','StartB_s'};
        if ~all(ismember(requiredPlanColumns, sessionPlan.Properties.VariableNames))
            error('exp00:invalidPlan', 'Session plan is missing required columns.');
        end
        if height(sessionPlan) ~= 180 || ~isequal(sessionPlan.TrialNum', 1:180)
            error('exp00:invalidPlan', 'Session plan must contain TrialNum 1 through 180 exactly once.');
        end
        planVideos = [sessionPlan.VideoA; sessionPlan.VideoB];
        planCategories = [sessionPlan.CategoryA; sessionPlan.CategoryB];
        planStarts = [sessionPlan.StartA_s; sessionPlan.StartB_s];
        [planVideos, firstIndex] = unique(planVideos, 'stable');
        poolT = table(planVideos, planCategories(firstIndex), planStarts(firstIndex), ...
            repmat(cclab.perClipSeconds, numel(planVideos), 1), ...
            'VariableNames', {'filename','category','start_s','shot_dur_s'});
        cclab.nTrials = height(sessionPlan);
        fprintf('\n--- exp_00 planned session (%d trials, %d source videos) ---\n', ...
            cclab.nTrials, height(poolT));
        fprintf('Plan: %s\n', sessionPlanFile);
    else
        poolT = readtable(cclab.poolFile, 'TextType', 'string');
        fprintf('\n--- exp_00 pilot pool (%d videos) ---\n', height(poolT));
    end
    nPool = height(poolT);
    for i = 1:nPool
        fprintf('  %-20s %-14s starts at %4.2fs (natural shot, %.1fs long)\n', ...
            poolT.filename(i), poolT.category(i), poolT.start_s(i), poolT.shot_dur_s(i));
    end
    fprintf('segDur=%gs, perClipSeconds=%gs (%d segments/clip), nTrials=%d\n\n', ...
        cclab.segDur, cclab.perClipSeconds, cclab.segsPerClip, cclab.nTrials);

    videoDir = fullfile(cclab.filepath, 'video_all');
    movieMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    timesShown = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:nPool
        fn = char(poolT.filename(i));
        fp = fullfile(videoDir, fn);
        if ~exist(fp, 'file')
            error('exp00:missingVideo', 'Pool video not found: %s', fp);
        end
        [movie, ~, ~, imgW, imgH] = Screen('OpenMovie', window, fp, 4);
        scaleFactor = screenYpixels / imgH;
        newWidth    = round(imgW * scaleFactor);
        leftX       = (screenXpixels - newWidth) / 2;
        m.ptr      = movie;
        m.rect     = [leftX, 0, leftX + newWidth, screenYpixels];
        m.category = char(poolT.category(i));
        m.startS   = poolT.start_s(i);
        movieMap(fn)   = m;
        timesShown(fn) = 0;
    end
    poolNames = keys(movieMap);

    %% 7) Setup EyeLink
    if useRealEyelink
        Eyelink('ShutDown');
        if ~EyelinkInit()
            warning('Could not init EyeLink. Forcing dummy mode...');
            useRealEyelink = false;
        end
    end

    if useRealEyelink
        % EyeLink EDF names are conservative alphanumeric identifiers; retain
        % the requested participant label in the output folder and MAT table.
        edfFile = regexprep(subID, '[^A-Za-z0-9_]', '');
        if Eyelink('OpenFile', edfFile) ~= 0
            fprintf('Cannot create EDF file %s', edfFile);
            cleanup; return
        end

        [ver, versionstring] = Eyelink('GetTrackerVersion');
        [~, vnumcell] = regexp(versionstring, '.*?(\d)\.\d*?', 'Match', 'Tokens');
        ELsoftwareVersion = str2double(vnumcell{1}{1});
        fprintf('Running experiment on %s version %d\n', versionstring, ver);

        AssertOpenGL;

        Eyelink('Command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('Command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,BUTTON,FIXUPDATE,INPUT');
        if ELsoftwareVersion > 3
            Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,HTARGET,GAZERES,BUTTON,STATUS,INPUT');
            Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,HTARGET,STATUS,INPUT');
        else
            Eyelink('Command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,RAW,AREA,GAZERES,BUTTON,STATUS,INPUT');
            Eyelink('Command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
        end

        el = EyelinkInitDefaults(window);
        scrDim = min(screenXpixels, screenYpixels);
        el.calibrationtargetsize   = 100 * (fixRad_px / scrDim);
        el.calibrationtargetwidth  = 0;
        el.backgroundcolour        = grey;
        el.calibrationtargetcolour = fixColor;
        el.msgfontcolour           = black;
        el.targetbeep              = 0;
        el.feedbackbeep            = 0;
        EyelinkUpdateDefaults(el);

        Eyelink('Command', 'screen_pixel_coords = 0 0 %d %d', screenXpixels-1, screenYpixels-1);
        Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, screenXpixels-1, screenYpixels-1);
        Eyelink('Command', 'calibration_type = HV9');
        Eyelink('Command', 'button_function 5 "accept_target_fixation"');
        Eyelink('Command', 'clear_screen 0');

        EyelinkDoTrackerSetup(el);
        WaitSecs(0.1);
    else
        fprintf('Running in dummy/mouse mode.\n');
    end

    %% 8) Results table — ONE ROW PER TRIAL
    outFolder = fullfile(pwd, 'Output_exp00_pilot', [subID '_' datestr(now,'yyyy-mm-dd_HHMM')]);
    if ~exist(outFolder, 'dir'), mkdir(outFolder); end
    outMat = fullfile(outFolder, [subID '_' datestr(now,'yyyy-mm-dd_HHMM') '.mat']);
    eventLog = fullfile(outFolder, 'event_log.csv');
    if useSessionPlan
        copyfile(sessionPlanFile, fullfile(outFolder, 'session_plan.csv'));
    end

    Results = table( ...
        'Size', [0 17], ...
        'VariableTypes', {'double','string','string','string','string','double', ...
                          'double','double','double', ...
        'double','double','double','string','double','double','string','string'}, ...
        'VariableNames', {'TrialNum','VideoA','CategoryA','VideoB','CategoryB','SameCategory', ...
                          'SegDur_s','TimesShownBeforeA','TimesShownBeforeB', ...
                          'FixAcquired_ms','InterleaveOff_ms','RewardOn_ms','AbortPhase', ...
                            'TrialSuccess','RewardSize','Participant','Experimenter'});
    segmentDiagnostics = struct('TrialNum', {}, 'Segment', {}, 'Movie', {}, ...
        'SeekToFirstFrame_ms', {}, 'MovieFrames', {}, 'MissedFlips', {}, ...
        'MeanFrameInterval_ms', {}, 'MaxFrameInterval_ms', {});

    total_success = 0;
    total_trials  = 0;
    break_out     = false;
    pauseRequested = false;
    pausedState = "";
    pauseStartedAt = NaN;
    activeTrial = struct('TrialNum', NaN, 'Phase', "Startup", 'VideoA', "", ...
        'VideoB', "", 'Segment', NaN, 'StartedAt', NaN);
    appendEvent(eventLog, 'SessionStart', NaN, NaN, ...
        sprintf('participant=%s;experimenter=%s', subID, cclab.experimenter));
    saveCheckpoint(outMat, Results, cclab, activeTrial);

    state = "Trial_start";
    trial_start_time = GetSecs;

    if useRealEyelink
        Eyelink('SetOfflineMode');
        Eyelink('StartRecording');
        WaitSecs(0.1);
        eyeUsed = Eyelink('EyeAvailable');
        if eyeUsed == 2, eyeUsed = 1; end
        Eyelink('Command', 'drift_correct_cr_disable = OFF');
        Eyelink('Command', 'online_dcorr_refposn %i,%i', centerX, centerY);
        Eyelink('StopRecording');
    else
        eyeUsed = NaN;
    end
    recordingActive = false;

    while ~break_out

        [~, ~, keyCode] = KbCheck;
        if keyCode(escKey)
            [exitConfirmed, pauseDuration] = confirmExit(window, escKey, eventLog, total_trials, state);
            if exitConfirmed
                fprintf('ESC confirmed, quitting.\n');
                activeTrial.Phase = "ExitConfirmed";
                saveCheckpoint(outMat, Results, cclab, activeTrial);
                state = "Exp_end";
            else
                % Do not count the confirmation dialog against fixation time.
                trial_start_time = trial_start_time + pauseDuration;
                if exist('trial_start_time_hold', 'var')
                    trial_start_time_hold = trial_start_time_hold + pauseDuration;
                end
                if state == "Wait_for_fixation" || state == "Hold_fix"
                    drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px);
                    Screen('Flip', window);
                end
                continue
            end
        elseif keyCode(pauseKey) && state ~= "Pause"
            if state == "Trial_start" || state == "Wait_for_fixation" || state == "Hold_fix"
                pausedState = state;
                pauseStartedAt = GetSecs;
                state = "Pause";
                appendEvent(eventLog, 'PauseEntered', total_trials, NaN, char(pausedState));
                emitControlMarker(useNeuralIO, cclab.pauseMarker, cclab.ttlPulseMs, ...
                    eventLog, total_trials, 'Pause');
                fprintf('PAUSED at trial %d (%s). Press Down Arrow to resume.\n', total_trials, pausedState);
            elseif ~pauseRequested
                pauseRequested = true;
                appendEvent(eventLog, 'PauseRequested', total_trials, NaN, char(state));
                fprintf(['Pause requested during trial %d (%s). This trial will finish and be saved; ' ...
                    'the task will pause before trial %d.\n'], total_trials, state, total_trials + 1);
            end
            KbReleaseWait;
        end

        if useRealEyelink && recordingActive
            err = Eyelink('CheckRecording');
            if err ~= 0
                fprintf('EyeLink Recording stopped!\n');
                Eyelink('SetOfflineMode');
                Eyelink('CloseFile');
                Eyelink('Command', 'clear_screen 0');
                WaitSecs(0.1);
                newFileName = [subID '_' datestr(now,'yyyy-mm-dd_HHMM') '_edf'];
                Eyelink('ReceiveFile', edfFile, fullfile(outFolder, newFileName), 1);
                Eyelink('ShutDown');
                cleanup; return
            end
        end

        switch state
            % -----------------------------------------------------------------
            case "Trial_start"
                total_trials = total_trials + 1;
                activeTrial = struct('TrialNum', total_trials, 'Phase', "Trial_start", ...
                    'VideoA', "", 'VideoB', "", 'Segment', NaN, 'StartedAt', GetSecs);
                appendEvent(eventLog, 'TrialStart', total_trials, NaN, '');
                saveCheckpoint(outMat, Results, cclab, activeTrial);
                fprintf('\n=== Trial #%d of %d (success so far=%d) ===\n', ...
                    total_trials, cclab.nTrials, total_success);
                printOperatorControls();
                abortPhase = "None";
                fixAcquiredMs   = NaN;
                interleaveOffMs = NaN;
                rewardOnMs      = NaN;
                rAmount         = 0;

                if useRealEyelink
                    Eyelink('StartRecording');
                    WaitSecs(0.05);
                    recordingActive = true;
                    Eyelink('Message', 'TrialStart_%d', total_trials);
                end

                drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px);
                Screen('Flip', window);

                trial_start_time = GetSecs;
                state = "Wait_for_fixation";

            % -----------------------------------------------------------------
            case "Wait_for_fixation"
                % No timeout — the dot waits as long as it takes. The only
                % way out of this state besides acquiring fixation is the
                % experimenter pressing ESC (checked at the top of this
                % loop, every iteration, regardless of state).
                inFix = checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, ...
                    fixWin_px, centerX, centerY, eyeUsed);

                if inFix
                    if useRealEyelink, Eyelink('Message', 'FixInFP_%d', total_trials); end
                    trial_start_time_hold = GetSecs;
                    state = "Hold_fix";
                end

            % -----------------------------------------------------------------
            case "Hold_fix"
                % Breaking fixation during the hold does NOT abort the
                % trial — it goes back to waiting and tries again,
                % indefinitely, same as Wait_for_fixation above.
                inFix = checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, ...
                    fixWin_px, centerX, centerY, eyeUsed);

                if ~inFix
                    state = "Wait_for_fixation";
                elseif (GetSecs - trial_start_time_hold) >= t_holdfix
                    fixAcquiredMs = 1000 * (GetSecs - trial_start_time);
                    state = "Select_and_play";
                end

            % -----------------------------------------------------------------
            case "Select_and_play"
                if useSessionPlan
                    planRow = sessionPlan(total_trials, :);
                    nameA = char(planRow.VideoA);
                    nameB = char(planRow.VideoB);
                else
                    % Pick 2 DISTINCT videos from the pilot pool, live, per trial.
                    pickIdx = randperm(nPool, 2);
                    nameA = poolNames{pickIdx(1)};
                    nameB = poolNames{pickIdx(2)};
                end
                mA = movieMap(nameA);
                mB = movieMap(nameB);
                if useSessionPlan
                    mA.startS = planRow.StartA_s;
                    mB.startS = planRow.StartB_s;
                end
                sameCategory = strcmp(mA.category, mB.category);
                activeTrial.Phase = "Select_and_play";
                activeTrial.VideoA = string(nameA);
                activeTrial.VideoB = string(nameB);
                appendEvent(eventLog, 'PairSelected', total_trials, NaN, ...
                    sprintf('A=%s;B=%s;sameCategory=%d', nameA, nameB, sameCategory));
                saveCheckpoint(outMat, Results, cclab, activeTrial);

                fprintf('\tA: %-20s (%s)   B: %-20s (%s)   same-category=%d\n', ...
                    nameA, mA.category, nameB, mB.category, sameCategory);

                aborted = false;
                forcedPause = false;
                for si = 1:cclab.segsPerClip
                    % Offset from each clip's OWN natural-shot start
                    % (pilot_pool.csv start_s), not always t=0 — some pool
                    % videos have a real cut before 6s in (see
                    % pilot_pool.csv/README for 00189DVD), so t=0 isn't
                    % always a safe/clean window.
                    segStartA = mA.startS + (si - 1) * cclab.segDur;
                    segStartB = mB.startS + (si - 1) * cclab.segDur;
                    activeTrial.Phase = "SegmentA";
                    activeTrial.Segment = si;
                    saveCheckpoint(outMat, Results, cclab, activeTrial);
                    [aborted, exitConfirmed, forcedPause, segmentPauseRequested, diag] = playOneSegment(window, mA, segStartA, cclab.segDur, ...
                        total_trials, si, 'A', useRealEyelink, useNeuralIO, escKey, pauseKey, forcePauseKey, cclab.ttlPulseMs, eventLog);
                    if segmentPauseRequested && ~pauseRequested
                        pauseRequested = true;
                        appendEvent(eventLog, 'PauseRequested', total_trials, si, 'during_movie');
                        fprintf('Pause requested during trial %d. The task will pause after this trial saves.\n', total_trials);
                    end
                    diag.TrialNum = total_trials; diag.Segment = si; diag.Movie = 'A';
                    segmentDiagnostics(end+1) = diag; %#ok<AGROW>
                    if exitConfirmed
                        activeTrial.Phase = "ExitConfirmed";
                        saveCheckpoint(outMat, Results, cclab, activeTrial);
                        break_out = true;
                        break
                    end
                    if aborted, break; end
                    activeTrial.Phase = "SegmentB";
                    activeTrial.Segment = si;
                    saveCheckpoint(outMat, Results, cclab, activeTrial);
                    [aborted, exitConfirmed, forcedPause, segmentPauseRequested, diag] = playOneSegment(window, mB, segStartB, cclab.segDur, ...
                        total_trials, si, 'B', useRealEyelink, useNeuralIO, escKey, pauseKey, forcePauseKey, cclab.ttlPulseMs, eventLog);
                    if segmentPauseRequested && ~pauseRequested
                        pauseRequested = true;
                        appendEvent(eventLog, 'PauseRequested', total_trials, si, 'during_movie');
                        fprintf('Pause requested during trial %d. The task will pause after this trial saves.\n', total_trials);
                    end
                    diag.TrialNum = total_trials; diag.Segment = si; diag.Movie = 'B';
                    segmentDiagnostics(end+1) = diag; %#ok<AGROW>
                    if exitConfirmed
                        activeTrial.Phase = "ExitConfirmed";
                        saveCheckpoint(outMat, Results, cclab, activeTrial);
                        break_out = true;
                        break
                    end
                    if aborted, break; end
                end

                if break_out, continue; end

                Screen('FillRect', window, [128 128 128]);
                Screen('Flip', window);
                KbReleaseWait;
                interleaveOffMs = 1000 * (GetSecs - trial_start_time);

                [~, ~, keyCode] = KbCheck;
                if aborted
                    if forcedPause
                        abortPhase = "ForcedPause";
                        pauseRequested = true;
                        appendEvent(eventLog, 'ForcedPauseRequested', total_trials, NaN, 'during_movie');
                        fprintf(['FORCED PAUSE: trial %d is being saved as aborted. ' ...
                            'The task will pause before trial %d.\n'], total_trials, total_trials + 1);
                    else
                        abortPhase = "Select_and_play";
                    end
                    state = "ITI";
                else
                    total_success = total_success + 1;
                    state = "Reward";
                end

            % -----------------------------------------------------------------
            case "Reward"
                activeTrial.Phase = "Reward";
                saveCheckpoint(outMat, Results, cclab, activeTrial);
                if useRealEyelink, Eyelink('Message', 'Reward_%d', total_trials); end

                Screen('FillRect', window, [128 128 128]);
                if ~isempty(rewardImg)
                    tex = Screen('MakeTexture', window, rewardImg);
                    Screen('DrawTexture', window, tex, [], dstRectReward);
                    Screen('Close', tex);
                else
                    DrawFormattedText(window, 'REWARD!', 'center', 'center', [0 255 0]);
                end
                Screen('Flip', window);

                rAmount = baseReward;
                if randReward && (rand() > randPer), rAmount = 2 * baseReward; end
                if useNeuralIO, cclabReward(rAmount, 1, 1000); end
                appendEvent(eventLog, 'Reward', total_trials, NaN, sprintf('duration_ms=%g', rAmount));
                rewardOnMs = 1000 * (GetSecs - trial_start_time);
                WaitSecs(t_reward);

                timesShown(nameA) = timesShown(nameA) + 1; %#ok<*NASGU>
                timesShown(nameB) = timesShown(nameB) + 1;

                state = "ITI";

            % -----------------------------------------------------------------
            case "ITI"
                Screen('FillRect', window, [128 128 128]);
                Screen('Flip', window);
                WaitSecs(t_ITI);

                % ITI is only ever reached after Select_and_play now (no
                % more fixation-timeout abort path), so abortPhase here is
                % always "None" or "Select_and_play" — a video pair was
                % always picked by this point.
                %
                % Report timesShown as it stood BEFORE this trial, so it
                % answers "how familiar was this pairing going in." Only a
                % completed trial (abortPhase=="None") already bumped
                % timesShown, in the Reward state — subtract that back out.
                if abortPhase == "None"
                    tsA = timesShown(nameA) - 1;
                    tsB = timesShown(nameB) - 1;
                else
                    tsA = timesShown(nameA);
                    tsB = timesShown(nameB);
                end
                row = { total_trials, string(nameA), string(mA.category), ...
                        string(nameB), string(mB.category), double(sameCategory), ...
                        cclab.segDur, tsA, tsB, ...
                        fixAcquiredMs, interleaveOffMs, rewardOnMs, abortPhase, ...
                        double(abortPhase == "None"), rAmount, string(subID), cclab.experimenter };
                Results(end+1, :) = row; %#ok<AGROW>
                activeTrial.Phase = "TrialComplete";
                saveCheckpoint(outMat, Results, cclab, activeTrial);
                appendEvent(eventLog, 'TrialSaved', total_trials, NaN, char(abortPhase));

                if useRealEyelink
                    Eyelink('StopRecording');
                    recordingActive = false;
                end

                if total_trials >= cclab.nTrials
                    fprintf('Completed %d of %d planned trials.\n', total_trials, cclab.nTrials);
                    state = "Exp_end";
                elseif pauseRequested
                    pauseRequested = false;
                    pausedState = "Trial_start";
                    pauseStartedAt = GetSecs;
                    state = "Pause";
                    appendEvent(eventLog, 'PauseEntered', total_trials, NaN, 'before_next_trial');
                    emitControlMarker(useNeuralIO, cclab.pauseMarker, cclab.ttlPulseMs, ...
                        eventLog, total_trials, 'Pause');
                    fprintf('PAUSED after trial %d. Press Down Arrow to begin trial %d.\n', ...
                        total_trials, total_trials + 1);
                else
                    state = "Trial_start";
                end

            % -----------------------------------------------------------------
            case "Pause"
                DrawFormattedText(window, 'PAUSED\nPress Down Arrow to resume', ...
                    'center', 'center', [255 255 0]);
                Screen('Flip', window);
                [~, ~, keyPause] = KbCheck;
                if keyPause(unpauseKey)
                    pauseDuration = GetSecs - pauseStartedAt;
                    if pausedState == "Wait_for_fixation" || pausedState == "Hold_fix"
                        trial_start_time = trial_start_time + pauseDuration;
                        if exist('trial_start_time_hold', 'var')
                            trial_start_time_hold = trial_start_time_hold + pauseDuration;
                        end
                        drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px);
                        Screen('Flip', window);
                    end
                    state = pausedState;
                    appendEvent(eventLog, 'PauseResumed', total_trials, NaN, char(pausedState));
                    emitControlMarker(useNeuralIO, cclab.resumeMarker, cclab.ttlPulseMs, ...
                        eventLog, total_trials, 'Resume');
                    fprintf('RESUMED at trial %d (%s).\n', total_trials, pausedState);
                    KbReleaseWait;
                end

            case "Exp_end"
                break_out = true;
        end
    end

    %% Close movies
    if ~isempty(segmentDiagnostics)
        writetable(struct2table(segmentDiagnostics), fullfile(outFolder, 'segment_diagnostics.csv'));
    end
    appendEvent(eventLog, 'SessionEnd', total_trials, NaN, sprintf('successes=%d', total_success));
    saveCheckpoint(outMat, Results, cclab, activeTrial);
    closeAllMovies(movieMap);

    %% Clean up EyeLink
    if useRealEyelink
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        Eyelink('ReceiveFile', edfFile, outFolder, 1);
        Eyelink('ShutDown');
    end

    if dioInitialized
        cclabCloseDIO();
        dioInitialized = false;
    end

    cleanup();

catch ME
    fprintf('\n!!! --- SCRIPT INTERRUPTED --- !!!\n');
    fprintf('An error occurred: %s\n', ME.message);

    try
        if ~exist('outFolder', 'var')
            outFolder = fullfile(pwd, 'Output_exp00_pilot', ...
                ['crash_' datestr(now,'yyyy-mm-dd_HHMM')]);
        end
        if ~exist(outFolder, 'dir'), mkdir(outFolder); end
        if ~exist('outMat', 'var')
            outMat = fullfile(outFolder, 'crash_data.mat');
        end

        if exist('Results', 'var') && exist('cclab', 'var')
            if ~exist('activeTrial', 'var')
                activeTrial = struct('TrialNum', NaN, 'Phase', "Error", 'VideoA', "", ...
                    'VideoB', "", 'Segment', NaN, 'StartedAt', NaN);
            else
                activeTrial.Phase = "Error";
            end
            saveCheckpoint(outMat, Results, cclab, activeTrial);
        elseif exist('cclab', 'var')
            save(outMat, 'cclab');
        end

        if exist('eventLog', 'var')
            appendEvent(eventLog, 'SessionError', NaN, NaN, ME.message);
        end

        fid = fopen(fullfile(outFolder, 'error_log.txt'), 'w');
        fprintf(fid, '%s\n\n%s', ME.message, getReport(ME));
        fclose(fid);
        fprintf('Saved crash diagnostics (partial data + error_log.txt) to:\n%s\n', outFolder);
    catch saveErr
        fprintf('Warning: failed to save crash diagnostics: %s\n', saveErr.message);
    end

    if dioInitialized
        cclabCloseDIO();
        dioInitialized = false;
    end

    if useRealEyelink
        Eyelink('StopRecording');
        Eyelink('CloseFile');
        try
            status = Eyelink('ReceiveFile', edfFile, outFolder, 1);
            if status > 0
                fprintf('EDF file successfully received and saved in:\n%s\n', outFolder);
            else
                fprintf('Warning: EDF file could not be received (Status: %d).\n', status);
            end
        catch receive_error
            fprintf('CRITICAL ERROR during Eyelink file reception: %s\n', receive_error.message);
        end
        Eyelink('ShutDown');
    end

    if exist('movieMap', 'var')
        closeAllMovies(movieMap);
    end

    cleanup();
    rethrow(ME);
end
end

% ---------------------------------------------------------------------------
function [aborted, exitConfirmed, forcedPause, pauseRequested, diag] = playOneSegment(window, m, segStart, segDur, trialNum, segIdx, which, useRealEyelink, useNeuralIO, escKey, pauseKey, forcePauseKey, ttlPulseMs, eventLog)
% Seek m to segStart, play for segDur, draw every frame. Returns true if
% ESC was pressed mid-segment.
aborted = false;
exitConfirmed = false;
forcedPause = false;
pauseRequested = false;
diag = struct('TrialNum', NaN, 'Segment', NaN, 'Movie', '', ...
    'SeekToFirstFrame_ms', NaN, 'MovieFrames', 0, 'MissedFlips', 0, ...
    'MeanFrameInterval_ms', NaN, 'MaxFrameInterval_ms', NaN);
seekStart = GetSecs;
Screen('SetMovieTimeIndex', m.ptr, segStart);
Screen('PlayMovie', m.ptr, 1);

segOnMarked = false;
segT0 = GetSecs;
lastFlipTime = NaN;
frameIntervalSum = 0;
frameIntervalCount = 0;
while (GetSecs - segT0) < segDur
    tex = Screen('GetMovieImage', window, m.ptr);
    if tex < 0, break; end
    if tex == 0
        WaitSecs('YieldSecs', 0.005);
        continue;
    end

    Screen('DrawTexture', window, tex, [], m.rect);
    [flipTime, ~, ~, missed] = Screen('Flip', window);
    Screen('Close', tex);
    diag.MovieFrames = diag.MovieFrames + 1;
    diag.MissedFlips = diag.MissedFlips + double(missed ~= 0);
    if isnan(lastFlipTime)
        diag.SeekToFirstFrame_ms = 1000 * (flipTime - seekStart);
    else
        frameInterval_ms = 1000 * (flipTime - lastFlipTime);
        frameIntervalSum = frameIntervalSum + frameInterval_ms;
        frameIntervalCount = frameIntervalCount + 1;
        if isnan(diag.MaxFrameInterval_ms) || frameInterval_ms > diag.MaxFrameInterval_ms
            diag.MaxFrameInterval_ms = frameInterval_ms;
        end
    end
    lastFlipTime = flipTime;

    if ~segOnMarked
        if useRealEyelink
            Eyelink('Message', 'SegOn_%d_%d_%s', trialNum, segIdx, which);
        end
        if useNeuralIO
            fprintf('TTL A: trial %d segment %d %s, %g ms\n', trialNum, segIdx, which, ttlPulseMs);
            cclabPulse('A', ttlPulseMs);
        end
        appendEvent(eventLog, 'SegmentOn', trialNum, segIdx, ...
            sprintf('movie=%s;ttl_ms=%g', which, ttlPulseMs));
        segOnMarked = true;
        segT0 = flipTime;
    end

    [~, ~, keyCode] = KbCheck;
    if keyCode(escKey)
        elapsedBeforePrompt = GetSecs - segT0;
        Screen('PlayMovie', m.ptr, 0);
        [exitConfirmed, pauseDuration] = confirmExit(window, escKey, eventLog, trialNum, "Select_and_play");
        if exitConfirmed
            aborted = true;
            break
        end
        Screen('SetMovieTimeIndex', m.ptr, segStart + elapsedBeforePrompt);
        Screen('PlayMovie', m.ptr, 1);
        segT0 = segT0 + pauseDuration;
    elseif keyCode(forcePauseKey)
        aborted = true;
        forcedPause = true;
        break
    elseif keyCode(pauseKey)
        pauseRequested = true;
    end
end

if frameIntervalCount > 0
    diag.MeanFrameInterval_ms = frameIntervalSum / frameIntervalCount;
end

Screen('PlayMovie', m.ptr, 0);
if useRealEyelink
    Eyelink('Message', 'SegOff_%d_%d_%s', trialNum, segIdx, which);
end
if useNeuralIO
    fprintf('TTL B: trial %d segment %d %s, %g ms\n', trialNum, segIdx, which, ttlPulseMs);
    cclabPulse('B', ttlPulseMs);
end
appendEvent(eventLog, 'SegmentOff', trialNum, segIdx, ...
    sprintf('movie=%s;ttl_ms=%g', which, ttlPulseMs));
end

function [confirmed, pauseDuration] = confirmExit(window, escKey, eventLog, trialNum, phase)
confirmed = false;
promptStart = GetSecs;
appendEvent(eventLog, 'ExitConfirmRequested', trialNum, NaN, char(phase));

windowRect = Screen('Rect', window);
oldTextSize = Screen('TextSize', window, 48);
DrawFormattedText(window, '?!', windowRect(3) - 90, 20, [255 0 0]);
Screen('Flip', window);
Screen('TextSize', window, oldTextSize);

KbReleaseWait;
deadline = promptStart + 3;
while GetSecs < deadline
    [~, ~, keyCode] = KbCheck;
    if keyCode(escKey)
        confirmed = true;
        break
    end
    WaitSecs('YieldSecs', 0.01);
end

pauseDuration = GetSecs - promptStart;
if confirmed
    appendEvent(eventLog, 'ExitConfirmed', trialNum, NaN, char(phase));
else
    appendEvent(eventLog, 'ExitConfirmExpired', trialNum, NaN, char(phase));
end
end

function saveCheckpoint(outMat, Results, cclab, activeTrial)
checkpoint = struct('savedAt', datestr(now, 31), 'activeTrial', activeTrial);
tempFile = [outMat '.tmp'];
save(tempFile, 'Results', 'cclab', 'checkpoint');
movefile(tempFile, outMat, 'f');
end

function appendEvent(eventLog, eventName, trialNum, segmentNum, detail)
isNew = ~exist(eventLog, 'file');
fid = fopen(eventLog, 'a');
if fid < 0, error('exp00:eventLog', 'Cannot open event log: %s', eventLog); end
cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
if isNew
    fprintf(fid, 'timestamp_local,event,trial,segment,detail\n');
end
detail = strrep(char(detail), '"', '""');
fprintf(fid, '%s,%s,%g,%g,"%s"\n', datestr(now, 31), eventName, trialNum, segmentNum, detail);
end

function emitControlMarker(useNeuralIO, marker, ttlPulseMs, eventLog, trialNum, action)
if useNeuralIO
    fprintf('TTL %s: %s, trial %d, %g ms\n', marker, action, trialNum, ttlPulseMs);
    cclabPulse(marker, ttlPulseMs);
end
appendEvent(eventLog, 'ControlMarker', trialNum, NaN, ...
    sprintf('action=%s;ttl=%s;ttl_ms=%g;io_enabled=%d', action, marker, ttlPulseMs, useNeuralIO));
end

function printOperatorControls()
fprintf(['CONTROLS: Up=safe pause; Down=resume; F=abort current movie trial then pause; ' ...
    'ESC then ESC within 3s=exit.\n']);
end

% ---------------------------------------------------------------------------
function drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px)
Screen('FillRect', window, [128 128 128]);
Screen('FillOval', window, fixColor, ...
    [centerX + fp_x_px - fixRad_px, centerY - fp_y_px - fixRad_px, ...
     centerX + fp_x_px + fixRad_px, centerY - fp_y_px + fixRad_px], 8);
end

% ---------------------------------------------------------------------------
function closeAllMovies(movieMap)
k = keys(movieMap);
for i = 1:numel(k)
    m = movieMap(k{i});
    try, Screen('CloseMovie', m.ptr); catch, end
end
end

%% checkFixation: uses EyeLink or Mouse
function inFix = checkFixation(useRealEyelink, window, xFixPx, yFixPx, fixWinPx, centerX, centerY, eyeUsed)
inFix = false;
if useRealEyelink
    evt = Eyelink('NewestFloatSample');
    if isempty(evt), return; end
    eye_idx = eyeUsed + 1;
    ex = evt.gx(eye_idx);
    ey = evt.gy(eye_idx);
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
sca;
ListenChar(0);
Priority(0);
end

%% exp_00 pilot — 2026-09-24, drastically simplified proof-of-stack variant
%% of exp_01, built alongside a PsychoPy template of the same design.
