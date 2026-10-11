function replacementCount = REPLACE_exp00_rejected_sources(candidateDir)
% REPLACE_exp00_rejected_sources Replace rejected QC sources without moving trials.
% The candidate metadata seed is retained; replacements are logged separately.
if nargin ~= 1 || ~(ischar(candidateDir) || isstring(candidateDir))
    error('exp00:replacementUsage', 'Usage: REPLACE_exp00_rejected_sources(candidateOutputFolder)');
end
candidateDir = char(candidateDir);
planFile = fullfile(candidateDir, 'session_plan.csv');
qcFile = fullfile(candidateDir, 'qc_source_windows.csv');
reviewFile = fullfile(candidateDir, 'qc_review.csv');
matFile = fullfile(candidateDir, 'session_plan.mat');
if exist(planFile, 'file') ~= 2 || exist(qcFile, 'file') ~= 2 || exist(reviewFile, 'file') ~= 2 || exist(matFile, 'file') ~= 2
    error('exp00:replacementInput', 'Candidate folder must contain plan, QC, review, and MAT files.');
end

plan = readtable(planFile, 'TextType', 'string');
qc = readtable(qcFile, 'TextType', 'string');
review = readtable(reviewFile, 'TextType', 'string');
loaded = load(matFile, 'metadata');
metadata = loaded.metadata;
design = metadata.design;
if height(qc) ~= 36 || numel(unique(string(qc.Video))) ~= 36
    error('exp00:replacementQC', 'QC sheet must contain 36 distinct sources.');
end

% Use each source's final review row, permitting a prior SKIP in the resumable log.
reviewStatus = strings(height(qc), 1);
reviewNotes = strings(height(qc), 1);
for i = 1:height(qc)
    matches = string(review.Video) == string(qc.Video(i)) & ...
        string(review.Start_s) == string(qc.Start_s(i)) & string(review.End_s) == string(qc.End_s(i));
    rows = find(matches);
    if isempty(rows)
        error('exp00:replacementReview', 'QC review is incomplete for %s.', qc.Video(i));
    end
    reviewStatus(i) = string(review.Status(rows(end)));
    if ismember('Notes', review.Properties.VariableNames)
        reviewNotes(i) = string(review.Notes(rows(end)));
    end
end
if any(~ismember(reviewStatus, ["PASS", "REJECT"]))
    error('exp00:replacementReview', 'Every QC source must be marked PASS or REJECT before replacement.');
end

rejected = find(reviewStatus == "REJECT");
replacementCount = numel(rejected);
if replacementCount == 0
    retainPassReviews(qc, reviewStatus, reviewNotes, reviewFile, qc);
    fprintf('All QC windows already pass; no replacements required.\n');
    return
end

logFile = fullfile(candidateDir, 'qc_replacements.csv');
priorReplacements = readReplacementLog(logFile);
excluded = [string(plan.VideoA); string(plan.VideoB); priorReplacements.ReplacedVideo; ...
    priorReplacements.ReplacementVideo; approvedHistory()];
rng(double(metadata.rngSeed) + height(priorReplacements), 'twister');
replacementRows = table();
for i = rejected'
    oldVideo = string(qc.Video(i));
    category = string(qc.Category(i));
    candidates = eligibleSources(category, design, excluded);
    if isempty(candidates)
        error('exp00:replacementPool', 'No eligible %s replacement remains for %s.', category, oldVideo);
    end
    replacement = candidates(randi(height(candidates)), :);
    excluded(end + 1, 1) = replacement.filename;
    [plan, metadata] = replaceInPlan(plan, metadata, oldVideo, replacement);
    replacementRows = [replacementRows; table(height(priorReplacements) + height(replacementRows) + 1, ...
        oldVideo, replacement.filename, category, string(qc.Start_s(i)), string(replacement.start_s), ...
        reviewNotes(i), string(datestr(now, 31)), 'VariableNames', ...
        {'ReplacementNumber','ReplacedVideo','ReplacementVideo','Category','OldStart_s','NewStart_s','Reason','ReplacedAt'})]; %#ok<AGROW>
end

if isempty(priorReplacements), replacementLog = replacementRows; else, replacementLog = [priorReplacements; replacementRows]; end
writetable(replacementLog, logFile);
writetable(plan, planFile);
save(matFile, 'plan', 'metadata');
writeQcArtifacts(plan, design, candidateDir);
newQc = readtable(qcFile, 'TextType', 'string');
retainPassReviews(qc, reviewStatus, reviewNotes, reviewFile, newQc);
fprintf('Replaced %d rejected QC source(s); logged to %s\n', replacementCount, logFile);
end

function [plan, metadata] = replaceInPlan(plan, metadata, oldVideo, replacement)
for side = ["A", "B"]
    videoColumn = "Video" + side;
    startColumn = "Start" + side + "_s";
    categoryColumn = "Category" + side;
    rows = string(plan.(videoColumn)) == oldVideo;
    if any(rows)
        if any(string(plan.(categoryColumn)(rows)) ~= replacement.category)
            error('exp00:replacementCategory', 'Replacement category does not match %s.', oldVideo);
        end
        plan.(videoColumn)(rows) = replacement.filename;
        plan.(startColumn)(rows) = replacement.start_s;
    end
end
sourceField = char(replacement.category + "Sources");
if isfield(metadata, sourceField)
    sourceRows = string(metadata.(sourceField).filename) == oldVideo;
    metadata.(sourceField)(sourceRows, :) = replacement;
end
end

function writeQcArtifacts(plan, design, candidateDir)
sourceA = table(plan.VideoA, plan.CategoryA, plan.StartA_s, 'VariableNames', {'Video','Category','Start_s'});
sourceB = table(plan.VideoB, plan.CategoryB, plan.StartB_s, 'VariableNames', {'Video','Category','Start_s'});
qcSources = sortrows(unique([sourceA; sourceB], 'rows', 'stable'), {'Category','Video'});
qcSources.End_s = qcSources.Start_s + design.secondsPerVideo;
writetable(qcSources, fullfile(candidateDir, 'qc_source_windows.csv'));
qcPairs = plan(plan.PairRepetition == 1, {'PairID','Condition','VideoA','StartA_s','VideoB','StartB_s'});
qcPairs.EndA_s = qcPairs.StartA_s + design.secondsPerVideo;
qcPairs.EndB_s = qcPairs.StartB_s + design.secondsPerVideo;
writetable(qcPairs, fullfile(candidateDir, 'qc_fixed_pairs.csv'));
end

function retainPassReviews(originalQc, statuses, notes, reviewFile, currentQc)
rows = table('Size', [0 6], 'VariableTypes', repmat("string", 1, 6), ...
    'VariableNames', {'Video','Category','Start_s','End_s','Status','Notes'});
for i = 1:height(originalQc)
    if statuses(i) == "PASS" && any(string(currentQc.Video) == string(originalQc.Video(i)))
        rows = [rows; {string(originalQc.Video(i)), string(originalQc.Category(i)), string(originalQc.Start_s(i)), ...
            string(originalQc.End_s(i)), "PASS", notes(i)}]; %#ok<AGROW>
    end
end
writetable(rows, reviewFile);
end

function replacements = readReplacementLog(logFile)
if exist(logFile, 'file') == 2
    replacements = readtable(logFile, 'TextType', 'string');
else
    replacements = table('Size', [0 8], 'VariableTypes', {'double','string','string','string','string','string','string','string'}, ...
        'VariableNames', {'ReplacementNumber','ReplacedVideo','ReplacementVideo','Category','OldStart_s','NewStart_s','Reason','ReplacedAt'});
end
end

function excluded = approvedHistory()
here = fileparts(mfilename('fullpath'));
history = readtable(fullfile(here, 'approved_source_history.csv'), 'TextType', 'string');
excluded = string(history.Video);
end

function sources = eligibleSources(category, design, excluded)
here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here)); data = fullfile(root, 'video_ebm_dataset');
manifest = readtable(fullfile(data, 'MANIFEST.csv'), 'TextType', 'string');
durations = readtable(fullfile(data, 'durations.csv'), 'TextType', 'string');
cuts = readtable(fullfile(data, 'cuts.csv'), 'TextType', 'string');
if category == "nature", mask = manifest.video_nature == 1; else, mask = manifest.video_social_undir == 1; end
stems = unique(stripExtension(manifest.filename(mask))); sources = table();
for i = 1:numel(stems)
    d = find(stripExtension(durations.filename) == stems(i), 1); c = find(stripExtension(cuts.filename) == stems(i), 1);
    if isempty(d) || isempty(c), continue; end
    boundaries = parseTimes(cuts.keyframes(c)); bounds = unique([0, boundaries, durations.duration_s(d)]);
    [shot, index] = max(diff(bounds)); filename = durations.filename(d);
    blocked = any(filename == excluded) || (category == "social" && any(contains(lower(filename), design.excludedSocialPatterns)));
    if shot >= design.secondsPerVideo + design.seekSafetyMargin_s && ~blocked
        sources = [sources; table(filename, category, bounds(index) + design.seekSafetyMargin_s, shot, ...
            'VariableNames', {'filename','category','start_s','longest_clean_shot_s'})]; %#ok<AGROW>
    end
end
end

function values = parseTimes(raw)
if strlength(raw) == 0, values = []; else, values = str2double(split(raw, ';'))'; end
end

function stem = stripExtension(filename)
stem = string(regexprep(filename, '\.[^.]+$', ''));
end
