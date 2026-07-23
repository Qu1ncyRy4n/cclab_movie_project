function trials = pseudorandomization(n_per_category, filepath)
% Returns a struct array of length 3*n_per_category describing the main
% trial sequence. Each group of 3 consecutive trials contains one nature,
% one social-directed, and one social-undirected video in a random order.
%
% Fields per element:
%   .filepath   full path to the .mp4 file
%   .name       filename only (for logging)
%   .category   'nature' | 'social_directed' | 'social_undir'
%
% Category membership is read from MANIFEST.csv so only video_all/ is
% needed on disk — no per-category subfolders required.

videoDir = fullfile(filepath, 'video_all');

% MANIFEST.csv lives in the repo (video_ebm_dataset/), not alongside the videos
scriptDir = fileparts(mfilename('fullpath'));
manifest  = fullfile(scriptDir, '..', 'video_ebm_dataset', 'MANIFEST.csv');

% Get all .mp4 files from video_all
allFiles = dir(fullfile(videoDir, '*.mp4'));

% Read MANIFEST and build per-category lists
T = readtable(manifest);
natureFiles      = filterByCategory(allFiles, T, 'video_nature',          videoDir);
directedFiles    = filterByCategory(allFiles, T, 'video_social_directed', videoDir);
notdirectedFiles = filterByCategory(allFiles, T, 'video_social_undir',    videoDir);

% Validate counts before attempting randperm
checkCount(numel(natureFiles),      n_per_category, 'video_nature',          videoDir, manifest);
checkCount(numel(directedFiles),    n_per_category, 'video_social_directed', videoDir, manifest);
checkCount(numel(notdirectedFiles), n_per_category, 'video_social_undir',    videoDir, manifest);

% Randomly select n_per_category from each category
selectedNature      = natureFiles(randperm(numel(natureFiles),      n_per_category));
selectedDirected    = directedFiles(randperm(numel(directedFiles),    n_per_category));
selectedNotdir      = notdirectedFiles(randperm(numel(notdirectedFiles), n_per_category));

% Interleave: each group of 3 has one from each category in a random order
trio = [selectedNature(1); selectedDirected(1); selectedNotdir(1)];
trials = trio(randperm(3));
for i = 2:n_per_category
    trio = [selectedNature(i); selectedDirected(i); selectedNotdir(i)];
    trials = [trials; trio(randperm(3))]; %#ok<AGROW>
end

end

% ---------------------------------------------------------------------------

function subset = filterByCategory(allFiles, T, colName, videoDir)
% Returns trial structs for files in video_all that MANIFEST marks as colName==1.
% Matching is done by basename (no extension) so MANIFEST need not be updated
% when video files are re-encoded to a different format.
categoryNames = string(T.filename(T.(colName) == 1));
[~, catBase, ~] = cellfun(@fileparts, cellstr(categoryNames), 'UniformOutput', false);
[~, allBase, ~] = cellfun(@fileparts, {allFiles.name},        'UniformOutput', false);
mask = ismember(allBase, catBase);
matchedFiles  = allFiles(mask);

category = strrep(colName, 'video_', '');
n = numel(matchedFiles);

if n == 0
    subset = struct('filepath', {}, 'name', {}, 'category', {});
    return;
end

for k = n:-1:1
    subset(k).filepath = fullfile(videoDir, matchedFiles(k).name);
    subset(k).name     = matchedFiles(k).name;
    subset(k).category = category;
end
subset = subset(:);
end

function checkCount(found, needed, category, videoDir, manifest)
if found < needed
    error('pseudorandomization:notEnoughFiles', ...
        ['%s: found %d .mp4 file(s) in\n  %s\nmatching MANIFEST, but need %d.\n' ...
         'Check that video_all/ is populated and %s is up to date.'], ...
        category, found, videoDir, needed, manifest);
end
end
