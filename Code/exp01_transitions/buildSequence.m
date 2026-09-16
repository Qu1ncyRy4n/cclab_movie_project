function trials = buildSequence(cclab)
% buildSequence  Build the per-trial segment playlists for exp_01.
%
% Returns a cell array; trials{i} is a struct array of SEGMENTS to play
% back to back in trial i. Both modes produce the same shape, so RUN_ has
% one playback loop.
%
% Segment fields:
%   .filepath    full path to the parent .mp4
%   .name        parent filename (logging)
%   .category    'nature' | 'social_directed' | 'social_undir'
%   .sourceFile  parent filename — same as .name; explicit so "same vs
%                different source" is recoverable in analysis
%   .startS      seek offset into the parent (s)
%   .durS        how long to play this segment (s)
%   .prevCat     category of the preceding segment ("" for trial start)
%   .transType   'N->D' etc., or 'trial_start'
%
% Clips are played in place with Screen('SetMovieTimeIndex') — nothing is
% split on disk, so MANIFEST needs no new rows.
%
% buildSequence('selftest') runs the balance//length checks with a synthetic
% pool and touches no files.

if nargin == 1 && ischar(cclab) && strcmp(cclab, 'selftest')
    selftest(); trials = {}; return;
end

pools = loadPools(cclab);
catNames = {'nature', 'social_directed', 'social_undir'};

switch lower(cclab.mode)
    case 'transitions'
        trials = buildTransitions(cclab, pools, catNames);
    case 'interleave'
        trials = buildInterleave(cclab, pools, catNames);
    otherwise
        error('buildSequence: unknown mode "%s" (expected transitions|interleave).', cclab.mode);
end
end

% ---------------------------------------------------------------------------
function trials = buildTransitions(cclab, pools, catNames)
% One cycle = the 9-symbol de Bruijn sequence, i.e. every ordered category
% pair exactly once. Cut into trials of cclab.clipsPerTrial clips; the cycle
% continues across trial boundaries.

segs = struct('filepath',{},'name',{},'category',{},'sourceFile',{}, ...
              'startS',{},'durS',{},'prevCat',{},'transType',{});

for c = 1:cclab.nCycles
    symbols = deBruijn3();
    for k = 1:numel(symbols)
        cat = catNames{symbols(k)};
        s = drawClip(pools, cat, cclab.clipDur);
        s.durS   = cclab.clipDur;
        if isempty(segs)
            s.prevCat = ""; s.transType = "trial_start";
        else
            s.prevCat   = string(segs(end).category);
            s.transType = shortName(segs(end).category) + "->" + shortName(cat);
        end
        segs(end+1) = s; %#ok<AGROW>
    end
end

trials = chunk(segs, cclab.clipsPerTrial);

% First segment of each trial follows a fixation + reward + ITI, not a cut.
for i = 1:numel(trials)
    trials{i}(1).transType = "trial_start";
    trials{i}(1).prevCat   = "";
end
end

% ---------------------------------------------------------------------------
function trials = buildInterleave(cclab, pools, catNames)
% One trial = one ordered category pair, its two clips alternating every
% cclab.interleaveSegDur seconds until each has had interleaveClipTotal
% seconds of screen time.

nSeg = round(cclab.interleaveClipTotal / cclab.interleaveSegDur);
if abs(nSeg * cclab.interleaveSegDur - cclab.interleaveClipTotal) > 1e-6
    error(['buildSequence: interleaveClipTotal (%g) must be a whole number of ' ...
           'segments of interleaveSegDur (%g).'], ...
           cclab.interleaveClipTotal, cclab.interleaveSegDur);
end

pairs = allOrderedPairs();   % 9 x 2 category indices
trials = {};

for c = 1:cclab.nCycles
    order = randperm(size(pairs,1));
    for p = order
        catA = catNames{pairs(p,1)};
        catB = catNames{pairs(p,2)};
        % Each clip needs interleaveClipTotal seconds of usable material.
        A = drawClip(pools, catA, cclab.interleaveClipTotal);
        B = drawClip(pools, catB, cclab.interleaveClipTotal);

        segs = struct('filepath',{},'name',{},'category',{},'sourceFile',{}, ...
                      'startS',{},'durS',{},'prevCat',{},'transType',{});
        for k = 1:(2*nSeg)
            useA = mod(k,2) == 1;
            if useA, s = A; else, s = B; end
            % Advance within the clip so the monkey never re-sees the same
            % footage — segment j of A starts where segment j-1 of A ended.
            nthOfThis = ceil(k/2) - 1;
            s.startS = s.startS + nthOfThis * cclab.interleaveSegDur;
            s.durS   = cclab.interleaveSegDur;
            if k == 1
                s.prevCat = ""; s.transType = "trial_start";
            else
                s.prevCat   = string(segs(end).category);
                s.transType = shortName(segs(end).category) + "->" + shortName(s.category);
            end
            segs(end+1) = s; %#ok<AGROW>
        end
        trials{end+1} = segs; %#ok<AGROW>
    end
end
end

% ---------------------------------------------------------------------------
function seq = deBruijn3()
% Order-2 de Bruijn sequence over 3 symbols: all 9 ordered pairs, each once,
% read cyclically. Hardcoded because it is 9 elements and correctness is
% checkable by eye; randomly relabelled and rotated so sessions differ.
% ponytail: hardcoded cycle + relabel/rotate. Write a Hierholzer walk only if
% the alphabet ever grows past 3 symbols.
base = [1 1 2 1 3 2 2 3 3];
relabel = randperm(3);
seq = relabel(base);
seq = circshift(seq, randi(numel(seq)));
end

function pairs = allOrderedPairs()
[a, b] = ndgrid(1:3, 1:3);
pairs = [a(:) b(:)];
end

% ---------------------------------------------------------------------------
function s = drawClip(pools, category, needS)
% Pick a random unused parent video of this category and a random start
% offset leaving at least needS seconds of material.
persistent used
if isempty(used), used = containers.Map('KeyType','char','ValueType','any'); end
if ~isKey(used, category), used(category) = {}; end

pool = pools.(category);
taken = used(category);
avail = pool(~ismember({pool.name}, taken));
if isempty(avail)
    % Pool exhausted for this session — reset and allow repeats rather than
    % aborting a run mid-session.
    warning('buildSequence:poolExhausted', ...
        '%s pool exhausted; allowing repeats.', category);
    used(category) = {}; taken = {}; avail = pool;
end

pick = avail(randi(numel(avail)));
taken{end+1} = pick.name;
used(category) = taken;

maxStart = max(0, pick.durationS - needS);
s.filepath   = pick.filepath;
s.name       = pick.name;
s.category   = category;
s.sourceFile = pick.name;
s.startS     = rand() * maxStart;
s.durS       = needS;
s.prevCat    = "";
s.transType  = "";
end

% ---------------------------------------------------------------------------
function pools = loadPools(cclab)
% Category pools from MANIFEST.csv, with per-file durations from
% durations.csv so clips are never requested past the end of a video.
videoDir = fullfile(cclab.filepath, 'video_all');

here     = fileparts(mfilename('fullpath'));          % Code/exp01_transitions
dataDir  = fullfile(here, '..', '..', 'video_ebm_dataset');
manifest = fullfile(dataDir, 'MANIFEST.csv');
durFile  = fullfile(dataDir, 'durations.csv');

allFiles = dir(fullfile(videoDir, '*.mp4'));
if isempty(allFiles)
    error('buildSequence:noVideos', 'No .mp4 files in %s', videoDir);
end

T = readtable(manifest);
if cclab.pilot
    T = T(T.pilot_ready == 1, :);
end

% durations.csv is produced by probe_durations.sh. Without it we cannot know
% a video is long enough for the requested clip — 8 of the 300 nature videos
% are shorter than 30 s (one is 7 s).
if exist(durFile, 'file')
    D = readtable(durFile);
    durMap = containers.Map(cellstr(string(D.filename)), num2cell(D.duration_s));
else
    warning('buildSequence:noDurations', ...
        ['%s not found — assuming every video is 30 s. Run probe_durations.sh ' ...
         'and commit the CSV; some nature videos are as short as 7 s.'], durFile);
    durMap = containers.Map('KeyType','char','ValueType','any');
end

cols = {'video_nature','video_social_directed','video_social_undir'};
for ci = 1:numel(cols)
    colName  = cols{ci};
    category = strrep(colName, 'video_', '');
    pools.(category) = poolFor(allFiles, T, colName, videoDir, durMap, cclab);
end
end

function subset = poolFor(allFiles, T, colName, videoDir, durMap, cclab)
% Match MANIFEST rows to files on disk by basename, so MANIFEST need not be
% updated when videos are re-encoded to another container.
catNames = string(T.filename(T.(colName) == 1));
[~, catBase]  = cellfun(@fileparts, cellstr(catNames), 'UniformOutput', false);
[~, diskBase] = cellfun(@fileparts, {allFiles.name},   'UniformOutput', false);
matched = allFiles(ismember(diskBase, catBase));

needS = max(cclab.clipDur, cclab.interleaveClipTotal);
subset = struct('filepath',{},'name',{},'durationS',{});
for k = 1:numel(matched)
    nm = matched(k).name;
    if isKey(durMap, nm), dur = durMap(nm); else, dur = 30.0; end
    if dur < needS
        continue;  % too short to yield a clip of the requested length
    end
    subset(end+1).filepath = fullfile(videoDir, nm); %#ok<AGROW>
    subset(end).name       = nm;
    subset(end).durationS  = dur;
end

if isempty(subset)
    error('buildSequence:emptyPool', ...
        ['%s: no video in\n  %s\nis both in MANIFEST (pilot=%d) and at least %g s long.\n' ...
         'Check video_all/, MANIFEST.csv and durations.csv.'], ...
        colName, videoDir, cclab.pilot, needS);
end
end

% ---------------------------------------------------------------------------
function out = chunk(segs, n)
out = {};
for i = 1:n:numel(segs)
    out{end+1} = segs(i:min(i+n-1, numel(segs))); %#ok<AGROW>
end
end

function s = shortName(category)
switch category
    case 'nature',          s = "N";
    case 'social_directed', s = "D";
    case 'social_undir',    s = "U";
    otherwise,              s = "?";
end
end

% ---------------------------------------------------------------------------
function selftest()
% Checks the sequencing logic only — no files, no MANIFEST, no PTB.
fprintf('buildSequence selftest...\n');

% de Bruijn: every ordered pair exactly once, read cyclically.
for rep = 1:50
    seq = deBruijn3();
    assert(numel(seq) == 9, 'de Bruijn cycle must be 9 long');
    seen = zeros(3);
    for k = 1:9
        a = seq(k); b = seq(mod(k,9)+1);
        seen(a,b) = seen(a,b) + 1;
    end
    assert(all(seen(:) == 1), 'every ordered pair must occur exactly once');
end

% Interleave segment maths: alternating, non-overlapping within each clip.
segDur = 2.5; total = 10;
nSeg = round(total/segDur);
assert(nSeg == 4, 'expected 4 segments per clip');
starts = (0:nSeg-1) * segDur;
assert(abs(starts(end) + segDur - total) < 1e-9, 'segments must tile the clip');

% chunk() must preserve order and lose nothing.
segs = struct('name', arrayfun(@(i) sprintf('s%d',i), 1:9, 'UniformOutput', false));
c = chunk(segs, 3);
assert(numel(c) == 3 && numel([c{:}]) == 9, 'chunk must preserve all segments');
assert(strcmp(c{2}(1).name, 's4'), 'chunk must preserve order');

fprintf('buildSequence selftest OK\n');
end
