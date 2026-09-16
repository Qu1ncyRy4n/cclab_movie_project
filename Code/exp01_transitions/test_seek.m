function test_seek()
% test_seek  Does PTB's SetMovieTimeIndex seek ACCURATELY or snap to keyframes?
%
% THIS GATES THE WHOLE exp_01 DESIGN. Clips are played by seeking into a
% parent video rather than splitting files on disk. The dataset is encoded
% with x264 defaults, so keyframes are ~8.34 s apart. If PTB snaps to the
% nearest keyframe, then asking for 2.5 s gets you 0 s, and interleave mode
% is silently broken — every segment shows the wrong footage.
%
% testdata/seek_test.mp4 is 30 s of PTB's own test pattern with the elapsed
% SECOND COUNT burned into the picture, encoded with the same sparse GOP as
% the dataset (keyframes at 0.00, 8.33, 16.67, 25.00).
%
% Run it, then read the number in each saved PNG:
%   requested 13.7 -> picture reads 13  => ACCURATE seek. Design holds.
%   requested 13.7 -> picture reads  8  => KEYFRAME SNAP. See remedies below.
%
% If it snaps:
%   (a) re-encode with dense keyframes (ffmpeg -g 25) — a full decode+encode
%       of 5.5 GB, so run it where the files live, not over the VPN; or
%   (b) restrict segment starts to real keyframes from cuts.csv — kills the
%       even 2.5 s interleave spacing; or
%   (c) split the clips to disk after all.

targets = [0.0 2.5 5.0 7.5 13.7 20.0 27.3];

here     = fileparts(mfilename('fullpath'));
videoFile = fullfile(here, 'testdata', 'seek_test.mp4');
outDir    = fullfile(pwd, 'seek_test_frames');

if ~exist(videoFile, 'file')
    error('test_seek:noVideo', ['Missing %s\nRegenerate with:\n' ...
        '  ffmpeg -f lavfi -i "testsrc=duration=30:size=640x480:rate=30" \\\n' ...
        '         -c:v libx264 -crf 28 -g 250 -pix_fmt yuv420p seek_test.mp4'], videoFile);
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

Screen('Preference', 'SkipSyncTests', 1);
try
    [window, ~] = PsychImaging('OpenWindow', 0, [128 128 128], [0 0 900 700]);
    movie = Screen('OpenMovie', window, videoFile);

    fprintf('\n  requested   saved frame\n');
    fprintf('  ---------   -----------\n');

    for t = targets
        Screen('SetMovieTimeIndex', movie, t);
        Screen('PlayMovie', movie, 1);

        % Grab the first real frame after the seek.
        tex = 0;
        t0  = GetSecs;
        while tex == 0 && (GetSecs - t0) < 5
            tex = Screen('GetMovieImage', window, movie);
            if tex == 0, WaitSecs('YieldSecs', 0.005); end
        end
        Screen('PlayMovie', movie, 0);

        if tex <= 0
            fprintf('  %7.1f s   FAILED to get a frame\n', t);
            continue
        end

        Screen('DrawTexture', window, tex, [], [0 0 640 480]);
        DrawFormattedText(window, sprintf('requested %.1f s', t), 20, 560, [255 255 255]);
        Screen('Flip', window);

        img = Screen('GetImage', window, [0 0 640 480]);
        fname = fullfile(outDir, sprintf('seek_%05.1f.png', t));
        imwrite(img, fname);
        fprintf('  %7.1f s   %s\n', t, fname);

        Screen('Close', tex);
        WaitSecs(0.6);   % long enough to read it off the screen live
    end

    Screen('CloseMovie', movie);
    sca;

    fprintf(['\nOpen the PNGs in %s and read the burned-in second count.\n' ...
             'Matches the request (13.7 -> "13")  => accurate seek, design holds.\n' ...
             'Snapped back (13.7 -> "8")          => keyframe snap, see remedies in this file.\n\n'], outDir);
catch ME
    sca;
    rethrow(ME);
end
end
