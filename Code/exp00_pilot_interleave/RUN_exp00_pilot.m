function RUN_exp00_pilot()
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

clear all
close all

useRealEyelink = false;
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

    prompt = {'Enter subID file name (up to 8 characters)'};
    answer = inputdlg(prompt, 'Create subID file', 1, {'demo'});
    if isempty(answer)
        fprintf('Session cancelled by user\n');
        error('Session cancelled by user');
    end
    subID = answer{1};
    if length(subID) > 8
        error('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)');
    end

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
    pauseKey   = KbName('PageUp');
    unpauseKey = KbName('PageDown');

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
    useRealEyelink = (dummymode_EYE == 0);
    if useRealEyelink
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

    %% 6) Load the 4-video pool and open each movie once
    poolT = readtable(cclab.poolFile, 'TextType', 'string');
    nPool = height(poolT);
    fprintf('\n--- exp_00 pilot pool (%d videos) ---\n', nPool);
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
        edfFile = subID;
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

    Results = table( ...
        'Size', [0 15], ...
        'VariableTypes', {'double','string','string','string','string','double', ...
                          'double','double','double', ...
                          'double','double','double','string','double','double'}, ...
        'VariableNames', {'TrialNum','VideoA','CategoryA','VideoB','CategoryB','SameCategory', ...
                          'SegDur_s','TimesShownBeforeA','TimesShownBeforeB', ...
                          'FixAcquired_ms','InterleaveOff_ms','RewardOn_ms','AbortPhase', ...
                          'TrialSuccess','RewardSize'});

    total_success = 0;
    total_trials  = 0;
    break_out     = false;

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
            fprintf('ESC pressed, quitting.\n'); state = "Exp_end";
        elseif keyCode(pauseKey)
            state = "Pause";
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
                fprintf('\n=== Trial #%d of %d (success so far=%d) ===\n', ...
                    total_trials, cclab.nTrials, total_success);
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
                % Pick 2 DISTINCT videos from the pool, live, per trial.
                pickIdx = randperm(nPool, 2);
                nameA = poolNames{pickIdx(1)};
                nameB = poolNames{pickIdx(2)};
                mA = movieMap(nameA);
                mB = movieMap(nameB);
                sameCategory = strcmp(mA.category, mB.category);

                fprintf('\tA: %-20s (%s)   B: %-20s (%s)   same-category=%d\n', ...
                    nameA, mA.category, nameB, mB.category, sameCategory);

                aborted = false;
                for si = 1:cclab.segsPerClip
                    % Offset from each clip's OWN natural-shot start
                    % (pilot_pool.csv start_s), not always t=0 — some pool
                    % videos have a real cut before 6s in (see
                    % pilot_pool.csv/README for 00189DVD), so t=0 isn't
                    % always a safe/clean window.
                    segStartA = mA.startS + (si - 1) * cclab.segDur;
                    segStartB = mB.startS + (si - 1) * cclab.segDur;
                    aborted = playOneSegment(window, mA, segStartA, cclab.segDur, ...
                        total_trials, si, 'A', useRealEyelink, escKey);
                    if aborted, break; end
                    aborted = playOneSegment(window, mB, segStartB, cclab.segDur, ...
                        total_trials, si, 'B', useRealEyelink, escKey);
                    if aborted, break; end
                end

                Screen('FillRect', window, [128 128 128]);
                Screen('Flip', window);
                KbReleaseWait;
                interleaveOffMs = 1000 * (GetSecs - trial_start_time);

                [~, ~, keyCode] = KbCheck;
                if aborted || keyCode(escKey)
                    abortPhase = "Select_and_play";
                    state = "ITI";
                else
                    total_success = total_success + 1;
                    state = "Reward";
                end

            % -----------------------------------------------------------------
            case "Reward"
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
                if useRealEyelink, cclabReward(rAmount, 1, 1000); end
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
                        double(abortPhase == "None"), rAmount };
                Results(end+1, :) = row; %#ok<AGROW>
                save(outMat, 'Results', 'cclab');

                if useRealEyelink
                    Eyelink('StopRecording');
                    recordingActive = false;
                end

                if total_trials >= cclab.nTrials
                    fprintf('Completed %d of %d planned trials.\n', total_trials, cclab.nTrials);
                    state = "Exp_end";
                else
                    state = "Trial_start";
                end

            % -----------------------------------------------------------------
            case "Pause"
                DrawFormattedText(window, 'PAUSED\n(Press PageDown (PgDn) to resume)', ...
                    'center', 'center', [255 255 0]);
                Screen('Flip', window);
                [~, ~, keyPause] = KbCheck;
                if keyPause(unpauseKey), state = "Trial_start"; end

            case "Exp_end"
                break_out = true;
        end
    end

    %% Close movies
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
            save(outMat, 'Results', 'cclab');
        elseif exist('cclab', 'var')
            save(outMat, 'cclab');
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
function aborted = playOneSegment(window, m, segStart, segDur, trialNum, segIdx, which, useRealEyelink, escKey)
% Seek m to segStart, play for segDur, draw every frame. Returns true if
% ESC was pressed mid-segment.
aborted = false;
Screen('SetMovieTimeIndex', m.ptr, segStart);
Screen('PlayMovie', m.ptr, 1);

segOnMarked = false;
segT0 = GetSecs;
while (GetSecs - segT0) < segDur
    tex = Screen('GetMovieImage', window, m.ptr);
    if tex < 0, break; end
    if tex == 0
        WaitSecs('YieldSecs', 0.005);
        continue;
    end

    Screen('DrawTexture', window, tex, [], m.rect);
    flipTime = Screen('Flip', window);
    Screen('Close', tex);

    if ~segOnMarked
        if useRealEyelink
            Eyelink('Message', 'SegOn_%d_%d_%s', trialNum, segIdx, which);
            cclabPulse('A');
        end
        segOnMarked = true;
        segT0 = flipTime;
    end

    [~, ~, keyCode] = KbCheck;
    if keyCode(escKey)
        aborted = true;
        break
    end
end

Screen('PlayMovie', m.ptr, 0);
if useRealEyelink
    Eyelink('Message', 'SegOff_%d_%d_%s', trialNum, segIdx, which);
    cclabPulse('B');
end
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
