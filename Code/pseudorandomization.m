function interleaved_movies = pseudorandomization(n_per_category, filepath)
% Produces a list of 3*n_per_category movies interleaved by category.
% Each group of 3 contains one nature, one social-directed, and one
% social-undirected video in a random order.
%
% Category membership is determined by MANIFEST.csv so only video_all/
% is needed on disk — no per-category subfolders required.

videoDir = fullfile(filepath, 'video_all');
manifest = fullfile(filepath, 'MANIFEST.csv');

% Get all .mpg files from video_all as proper dir() structs
allFiles = dir(fullfile(videoDir, '*.mpg'));

% Read MANIFEST and filter by category
T = readtable(manifest);
natureFiles      = filterByCategory(allFiles, T, 'video_nature');
directedFiles    = filterByCategory(allFiles, T, 'video_social_directed');
notdirectedFiles = filterByCategory(allFiles, T, 'video_social_undir');

% Validate that enough files are available
checkCount(numel(natureFiles),      n_per_category, 'video_nature',          videoDir, manifest);
checkCount(numel(directedFiles),    n_per_category, 'video_social_directed', videoDir, manifest);
checkCount(numel(notdirectedFiles), n_per_category, 'video_social_undir',    videoDir, manifest);

% Randomly select n_per_category from each category
selectedNature      = natureFiles(randperm(numel(natureFiles),      n_per_category));
selectedDirected    = directedFiles(randperm(numel(directedFiles),    n_per_category));
selectedNotdir      = notdirectedFiles(randperm(numel(notdirectedFiles), n_per_category));

% Interleave: each group of 3 has one from each category in a random order
trio = [selectedNature(1); selectedDirected(1); selectedNotdir(1)];
interleaved_movies = trio(randperm(3));
for i = 2:n_per_category
    trio = [selectedNature(i); selectedDirected(i); selectedNotdir(i)];
    interleaved_movies = [interleaved_movies; trio(randperm(3))]; %#ok<AGROW>
end

end

% ---------------------------------------------------------------------------

function subset = filterByCategory(allFiles, T, colName)
% Returns the subset of allFiles whose names appear in MANIFEST with colName==1
categoryNames = string(T.filename(T.(colName) == 1));
allNames      = string({allFiles.name}');
subset        = allFiles(ismember(allNames, categoryNames));
end

function checkCount(found, needed, category, videoDir, manifest)
if found < needed
    error('pseudorandomization:notEnoughFiles', ...
        ['%s: found %d .mpg file(s) in "%s" matching MANIFEST, but need %d.\n' ...
         'Check that video_all/ is populated and %s is up to date.'], ...
        category, found, videoDir, needed, manifest);
end
end
