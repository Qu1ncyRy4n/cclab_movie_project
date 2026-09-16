function RUN_exp01_transitions()
% RUN_exp01_transitions
%
% exp_01: free viewing across video transitions.
%
% The monkey acquires fixation, then watches a playlist of video SEGMENTS
% played back to back. A segment is a time window of a parent video, seeked
% to in place — nothing is split on disk. Both designs come out of the same
% loop (see CONFI cclab.mode):
%   'transitions' — clips in de Bruijn order, every ordered category pair
%   'interleave'  — two clips alternating every 2.5 s
%
% Results has ONE ROW PER SEGMENT (not per trial), since the segment is the
% unit of analysis.
%
% Adapted from RUN_freeviewingTraining_movie.m (O. Soyuhos 2025, S. Novik 2026).

clear all
close all

useRealEyelink = false;
dioInitialized = false;

try
    %% 1) Load config
    cclab = CONFI_exp01_transitions();

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

    t_waitfix     = cclab.durations.t_waitfixation_fp;
    t_holdfix     = cclab.durations.t_fixation_fp;
    t_ITI         = cclab.durations.t_trialend;
    t_reward      = cclab.durations.t_reward;
    t_fix_between = cclab.durations.t_fix_between;
    t_waitfix_bt  = cclab.durations.t_waitfix_between;

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

    %% 6) Build the trial playlists
    trials     = buildSequence(cclab);
    nTrials    = numel(trials);
    nSegsTotal = sum(cellfun(@numel, trials));

    fprintf('\n--- Planned sequence: mode=%s, %d trials, %d segments ---\n', ...
        cclab.mode, nTrials, nSegsTotal);
    for ti = 1:nTrials
        fprintf('  Trial %d:\n', ti);
        for si = 1:numel(trials{ti})
            s = trials{ti}(si);
            fprintf('    [%d] %-16s %6.2f-%6.2f s  %-12s  %s\n', ...
                si, s.category, s.startS, s.startS + s.durS, s.transType, s.name);
        end
    end
    fprintf('----------------------------------------------\n\n');

    %% 7) Open each distinct parent video ONCE
    % A parent can appear in many segments (always in interleave mode), so
    % movies are keyed by filepath and seeked per segment rather than reopened.
    movieMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for ti = 1:nTrials
        for si = 1:numel(trials{ti})
            fp = trials{ti}(si).filepath;
            if isKey(movieMap, fp), continue; end
            [movie, ~, ~, imgW, imgH] = Screen('OpenMovie', window, fp, 4);

            scaleFactor = screenYpixels / imgH;
            newWidth    = round(imgW * scaleFactor);
            leftX       = (screenXpixels - newWidth) / 2;

            m.ptr  = movie;
            m.rect = [leftX, 0, leftX + newWidth, screenYpixels];
            m.w    = imgW;
            m.h    = imgH;
            movieMap(fp) = m;
        end
    end
    fprintf('Opened %d distinct movie files.\n', movieMap.Count);

    %% 8) Setup EyeLink
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

    %% 9) Results table — ONE ROW PER SEGMENT
    outFolder = fullfile(pwd, 'Output_exp01_transitions', [subID '_' datestr(now,'yyyy-mm-dd_HHMM')]);
    if ~exist(outFolder, 'dir'), mkdir(outFolder); end
    outMat = fullfile(outFolder, [subID '_' datestr(now,'yyyy-mm-dd_HHMM') '.mat']);

    Results = table( ...
        'Size', [0 16], ...
        'VariableTypes', {'double','double','string','string','string','string', ...
                          'double','double','string','string','cell', ...
                          'double','double','double','double','string'}, ...
        'VariableNames', {'TrialNum','SegIndex','Mode','MovieFile','MovieCategory','SourceFile', ...
                          'ClipStart_s','SegDur_s','PrevCategory','TransitionType','SegRect', ...
                          'SegOn','SegOff','TrialSuccess','RewardSize','AbortPhase'});

    total_success = 0;
    total_trials  = 0;
    break_out     = false;
    trialPtr      = 1;

    state = "Trial_start";
    trial_start_time = GetSecs;

    %% EyeLink bootstrap — determine tracked eye, set drift correction
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

        % ---------- experimenter keys ----------
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
                status = Eyelink('ReceiveFile', edfFile, fullfile(outFolder, newFileName), 1);
                if status == 0
                    fprintf('File received and saved as %s\n', fullfile(outFolder, newFileName));
                else
                    fprintf('Error receiving file.\n');
                end
                Eyelink('ShutDown');
                cleanup; return
            end
        end

        switch state
            % -----------------------------------------------------------------
            case "Trial_start"
                total_trials = total_trials + 1;
                thisPlaylist = trials{trialPtr};
                fprintf('\n=== Trial #%d of %d (%d segments, success so far=%d) ===\n', ...
                    total_trials, nTrials, numel(thisPlaylist), total_success);

                segRows    = [];   % accumulates one struct per played segment
                abortPhase = "None";

                if useRealEyelink
                    Eyelink('StartRecording');
                    WaitSecs(0.05);
                    recordingActive = true;
                    Eyelink('Message', 'TrialStart_%d', total_trials);
                end

                drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px);
                Screen('Flip', window);

                if useRealEyelink
                    Eyelink('command', 'clear_screen 0');
                    Eyelink('Command', sprintf('draw_box %d %d %d %d 15', ...
                        centerX + fp_x_px - fixWin_px/2, centerY - fp_y_px - fixWin_px/2, ...
                        centerX + fp_x_px + fixWin_px/2, centerY - fp_y_px + fixWin_px/2));
                end

                trial_start_time = GetSecs;
                state = "Wait_for_fixation";

            % -----------------------------------------------------------------
            case "Wait_for_fixation"
                inFix = checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, ...
                    fixWin_px, centerX, centerY, eyeUsed);

                if inFix
                    if useRealEyelink, Eyelink('Message', 'FixInFP_%d', total_trials); end
                    trial_start_time_hold = GetSecs;
                    state = "Hold_fix";
                elseif (GetSecs - trial_start_time) > t_waitfix
                    fprintf('\tFailed to acquire fixation.\n');
                    abortPhase = "Wait_for_fixation";
                    state = "ITI";
                end

            % -----------------------------------------------------------------
            case "Hold_fix"
                inFix = checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, ...
                    fixWin_px, centerX, centerY, eyeUsed);

                if ~inFix
                    fprintf('\tBroke fixation.\n');
                    abortPhase = "Hold_fix";
                    state = "ITI";
                elseif (GetSecs - trial_start_time_hold) >= t_holdfix
                    state = "Play_segments";
                end

            % -----------------------------------------------------------------
            case "Play_segments"
                aborted = false;

                for si = 1:numel(thisPlaylist)
                    seg = thisPlaylist(si);
                    m   = movieMap(seg.filepath);

                    % Fixation between segments (not before the first — the
                    % trial-start fixation just ended).
                    if si > 1 && t_fix_between > 0
                        ok = holdFixationFor(window, fixColor, centerX, centerY, ...
                            fp_x_px, fp_y_px, fixRad_px, fixWin_px, ...
                            t_fix_between, t_waitfix_bt, useRealEyelink, eyeUsed);
                        if ~ok
                            fprintf('\tBroke/failed fixation between segments (seg %d).\n', si);
                            abortPhase = "Fix_between";
                            aborted = true;
                            break
                        end
                        if useRealEyelink
                            Eyelink('Message', 'FixBetween_%d_%d', total_trials, si);
                        end
                    end

                    fprintf('\t[seg %d] %-16s %6.2f-%6.2f s  %-12s  %s\n', ...
                        si, seg.category, seg.startS, seg.startS + seg.durS, ...
                        seg.transType, seg.name);

                    % Seek to the segment start, then play for seg.durS.
                    % ponytail: SetMovieTimeIndex may snap to the nearest
                    % keyframe. If the encoded GOP turns out to be long, either
                    % re-encode with -g 25 -force_key_frames or align segment
                    % boundaries to keyframes. Check with:
                    %   ffprobe -select_streams v:0 -skip_frame nokey \
                    %           -show_entries frame=pts_time -of csv=p=0 FILE
                    Screen('SetMovieTimeIndex', m.ptr, seg.startS);
                    Screen('PlayMovie', m.ptr, 1);

                    segOnMarked = false;
                    segOnTime   = NaN;
                    segT0       = GetSecs;

                    while (GetSecs - segT0) < seg.durS
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
                            segOnTime = flipTime;
                            if useRealEyelink
                                Eyelink('Message', 'SegOn_%d_%d', total_trials, si);
                                cclabPulse('A');   % TTL sync, segment onset
                            end
                            segOnMarked = true;
                            segT0 = flipTime;      % time the segment from first frame
                        end

                        [~, ~, keyCode] = KbCheck;
                        if keyCode(escKey)
                            fprintf('ESC pressed, quitting.\n');
                            state = "Exp_end";
                            break
                        end
                    end

                    Screen('PlayMovie', m.ptr, 0);
                    segOffTime = GetSecs;
                    if useRealEyelink
                        Eyelink('Message', 'SegOff_%d_%d', total_trials, si);
                        cclabPulse('B');           % TTL sync, segment offset
                    end

                    segRows = [segRows; makeSegRow(seg, total_trials, si, cclab.mode, ...
                        segOnTime, segOffTime, trial_start_time, m.rect)]; %#ok<AGROW>

                    if state == "Exp_end"
                        aborted = true;
                        break
                    end
                end

                Screen('FillRect', window, [128 128 128]);
                Screen('Flip', window);
                KbReleaseWait;

                if state == "Exp_end"
                    state = "ITI";
                elseif aborted
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
                WaitSecs(t_reward);

                for r = 1:numel(segRows)
                    segRows(r).TrialSuccess = 1;
                    segRows(r).RewardSize   = rAmount;
                end

                trialPtr = trialPtr + 1;
                state = "ITI";

            % -----------------------------------------------------------------
            case "ITI"
                Screen('FillRect', window, [128 128 128]);
                Screen('Flip', window);
                WaitSecs(t_ITI);

                for r = 1:numel(segRows)
                    segRows(r).AbortPhase = abortPhase;
                    Results(end+1, :) = struct2table(segRows(r), 'AsArray', true);
                end
                save(outMat, 'Results', 'cclab');

                if useRealEyelink
                    Eyelink('StopRecording');
                    recordingActive = false;
                end

                if trialPtr > nTrials
                    fprintf('Completed all %d trials.\n', nTrials);
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

    % Best-effort save so a crash never means zero data on disk.
    try
        if ~exist('outFolder', 'var')
            outFolder = fullfile(pwd, 'Output_exp01_transitions', ...
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
        Eyelink('ShutDown');
        fprintf('Eyelink shut down.\n');
    end

    if exist('movieMap', 'var')
        closeAllMovies(movieMap);
    end

    cleanup();
    rethrow(ME);
end
end

% ---------------------------------------------------------------------------
function row = makeSegRow(seg, trialNum, segIdx, mode, segOn, segOff, trialStart, rect)
% Latencies in ms relative to trial start, matching the original task.
row = struct( ...
    'TrialNum'      , trialNum, ...
    'SegIndex'      , segIdx, ...
    'Mode'          , string(mode), ...
    'MovieFile'     , string(seg.name), ...
    'MovieCategory' , string(seg.category), ...
    'SourceFile'    , string(seg.sourceFile), ...
    'ClipStart_s'   , seg.startS, ...
    'SegDur_s'      , seg.durS, ...
    'PrevCategory'  , string(seg.prevCat), ...
    'TransitionType', string(seg.transType), ...
    'SegRect'       , {rect}, ...
    'SegOn'         , 1000*(segOn  - trialStart), ...
    'SegOff'        , 1000*(segOff - trialStart), ...
    'TrialSuccess'  , 0, ...
    'RewardSize'    , 0, ...
    'AbortPhase'    , "None");
end

% ---------------------------------------------------------------------------
function drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px)
Screen('FillRect', window, [128 128 128]);
Screen('FillOval', window, fixColor, ...
    [centerX + fp_x_px - fixRad_px, centerY - fp_y_px - fixRad_px, ...
     centerX + fp_x_px + fixRad_px, centerY - fp_y_px + fixRad_px], 8);
end

% ---------------------------------------------------------------------------
function ok = holdFixationFor(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, ...
    fixRad_px, fixWin_px, holdDur, waitDur, useRealEyelink, eyeUsed)
% Show the dot; require fixation to be acquired within waitDur and then held
% for holdDur. Returns false if either fails.
drawFixation(window, fixColor, centerX, centerY, fp_x_px, fp_y_px, fixRad_px);
Screen('Flip', window);

t0 = GetSecs;
acquired = false;
while (GetSecs - t0) < waitDur
    if checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, fixWin_px, centerX, centerY, eyeUsed)
        acquired = true;
        break
    end
end
if ~acquired, ok = false; return; end

tHold = GetSecs;
while (GetSecs - tHold) < holdDur
    if ~checkFixation(useRealEyelink, window, fp_x_px, fp_y_px, fixWin_px, centerX, centerY, eyeUsed)
        ok = false; return
    end
end
ok = true;
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

%% Orhan Soyuhos, 2025
% Modified by Shoshana Novik, 2026, for the movie freeviewing task
% exp_01 transitions variant, 2026
