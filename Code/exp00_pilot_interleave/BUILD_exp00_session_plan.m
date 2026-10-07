function plan = BUILD_exp00_session_plan(randomSeed)
% BUILD_exp00_session_plan Construct and verify the confirmed 10x18 session.
% This precomputes the full plan; it does not alter RUN_exp00_pilot yet.
if nargin < 1, randomSeed = 'shuffle'; end
rng(randomSeed);
design = DESIGN_exp00_session();
if design.epochs * design.trialsPerConditionPerEpoch ~= 60
    error('exp00:design', 'This builder expects 60 trials per condition.');
end

[nature, social] = loadEligibleSources(design);
if height(nature) < design.sourcesPerCategory || height(social) < design.sourcesPerCategory
    error('exp00:pool', 'Need %d eligible sources per category.', design.sourcesPerCategory);
end
nature = nature(randperm(height(nature), design.sourcesPerCategory), :);
social = social(randperm(height(social), design.sourcesPerCategory), :);
nsNature = roleMatrix(design.sourcesPerCategory, design.epochs);
nsSocial = roleMatrix(design.sourcesPerCategory, design.epochs);

usedNN = strings(0, 1); usedSS = strings(0, 1); usedNS = strings(0, 1);
rows = cell(design.epochs * 18, 10); row = 0;
previousCondition = "";
for epoch = 1:design.epochs
    nNS = nature(nsNature(epoch, :), :); nNN = nature(~nsNature(epoch, :), :);
    sNS = social(nsSocial(epoch, :), :); sSS = social(~nsSocial(epoch, :), :);
    [nnPairs, usedNN] = newPairs(nNN, usedNN);
    [ssPairs, usedSS] = newPairs(sSS, usedSS);
    [nsPairs, usedNS] = newMixedPairs(nNS, sNS, usedNS);
    labels = conditionOrder(design, previousCondition);
    previousCondition = labels(end);
    nnIndex = 1; ssIndex = 1; nsIndex = 1;
    for trialInEpoch = 1:numel(labels)
        condition = labels(trialInEpoch);
        switch condition
            case "NN", pair = nnPairs{nnIndex}; nnIndex = nnIndex + 1;
            case "SS", pair = ssPairs{ssIndex}; ssIndex = ssIndex + 1;
            case "NS", pair = nsPairs{nsIndex}; nsIndex = nsIndex + 1;
        end
        if condition == "NS" && mod(nsIndex - 1, 2) == 0
            pair = pair([2 1], :);
        end
        row = row + 1;
        rows(row, :) = {epoch, trialInEpoch, row, condition, pair.filename(1), ...
            pair.filename(2), pair.category(1), pair.category(2), ...
            pair.start_s(1), pair.start_s(2)};
    end
end
plan = cell2table(rows, 'VariableNames', {'Epoch', 'TrialInEpoch', 'TrialNum', ...
    'Condition', 'VideoA', 'VideoB', 'CategoryA', 'CategoryB', 'StartA_s', 'StartB_s'});
plan.Epoch = cell2mat(plan.Epoch);
plan.TrialInEpoch = cell2mat(plan.TrialInEpoch);
plan.TrialNum = cell2mat(plan.TrialNum);
plan.Condition = string(plan.Condition);
plan.VideoA = string(plan.VideoA); plan.VideoB = string(plan.VideoB);
plan.CategoryA = string(plan.CategoryA); plan.CategoryB = string(plan.CategoryB);
plan.StartA_s = cell2mat(plan.StartA_s); plan.StartB_s = cell2mat(plan.StartB_s);
verifyPlan(plan, design, nature, social);
end

function matrix = roleMatrix(nSources, nEpochs)
% Each source is mixed-category 3 or 4 times, 60 assignments in total.
quota = [repmat(4, 1, 6), repmat(3, 1, nSources - 6)];
for attempt = 1:10000
    ids = repelem(randperm(nSources), quota);
    ids = ids(randperm(numel(ids)));
    matrix = false(nEpochs, nSources);
    valid = true;
    for epoch = 1:nEpochs
        chunk = ids((epoch - 1) * 6 + (1:6));
        if numel(unique(chunk)) ~= 6, valid = false; break; end
        matrix(epoch, chunk) = true;
    end
    if valid, return; end
end
error('exp00:roles', 'Could not distribute mixed-category roles.');
end

function [pairs, used] = newPairs(sources, used)
for attempt = 1:5000
    order = randperm(height(sources));
    keys = pairKeys(sources.filename(order(1:2:end)), sources.filename(order(2:2:end)));
    if numel(unique(keys)) == numel(keys) && ~any(ismember(keys, used))
        pairs = cell(numel(keys), 1);
        for i = 1:numel(keys)
            pairs{i} = sources(order((i - 1) * 2 + (1:2)), :);
        end
        used = [used; keys]; return
    end
end
error('exp00:pairs', 'Could not construct non-repeated within-category pairs.');
end

function [pairs, used] = newMixedPairs(nature, social, used)
for attempt = 1:5000
    order = randperm(height(social));
    keys = pairKeys(nature.filename, social.filename(order));
    if numel(unique(keys)) == numel(keys) && ~any(ismember(keys, used))
        pairs = cell(numel(keys), 1);
        for i = 1:numel(keys)
            pairs{i} = [nature(i, :); social(order(i), :)];
        end
        used = [used; keys]; return
    end
end
error('exp00:pairs', 'Could not construct non-repeated mixed-category pairs.');
end

function keys = pairKeys(a, b)
keys = strings(numel(a), 1);
for i = 1:numel(a)
    names = sort([string(a(i)), string(b(i))]);
    keys(i) = names(1) + "|" + names(2);
end
end

function labels = conditionOrder(design, previousCondition)
for attempt = 1:10000
    labels = repelem(design.conditions, design.trialsPerConditionPerEpoch);
    labels = labels(randperm(numel(labels)));
    runLength = 1; valid = true;
    for i = 2:numel(labels)
        if labels(i) == labels(i - 1), runLength = runLength + 1; else, runLength = 1; end
        if runLength > design.maxConditionRun, valid = false; break; end
    end
    if valid && (previousCondition == "" || labels(1) ~= previousCondition), return; end
end
error('exp00:conditionOrder', 'Could not construct condition order.');
end

function verifyPlan(plan, design, nature, social)
assert(height(plan) == 180, 'exp00:trialCount');
assert(all(countcats(categorical(plan.Condition, design.conditions)) == 60), 'exp00:conditionCount');
allVideos = [plan.VideoA; plan.VideoB];
assert(all(sum(allVideos == nature.filename', 1) == design.repetitionsPerSource), 'exp00:natureCounts');
assert(all(sum(allVideos == social.filename', 1) == design.repetitionsPerSource), 'exp00:socialCounts');
keys = pairKeys(plan.VideoA, plan.VideoB);
assert(numel(unique(keys)) == height(plan), 'exp00:repeatedPair');
assert(sum(plan.Condition == "NS" & plan.CategoryA == "nature") == 30, 'exp00:mixedOrder');
end

function [nature, social] = loadEligibleSources(design)
here = fileparts(mfilename('fullpath')); root = fileparts(fileparts(here)); data = fullfile(root, 'video_ebm_dataset');
manifest = readtable(fullfile(data, 'MANIFEST.csv'), 'TextType', 'string');
durations = readtable(fullfile(data, 'durations.csv'), 'TextType', 'string');
cuts = readtable(fullfile(data, 'cuts.csv'), 'TextType', 'string');
nature = eligible(manifest, durations, cuts, manifest.video_nature == 1, "nature", design);
social = eligible(manifest, durations, cuts, manifest.video_social_undir == 1, "social", design);
end

function sources = eligible(manifest, durations, cutsTable, mask, category, design)
stems = unique(stripExtension(manifest.filename(mask))); sources = table();
for i = 1:numel(stems)
    d = find(stripExtension(durations.filename) == stems(i), 1); c = find(stripExtension(cutsTable.filename) == stems(i), 1);
    if isempty(d) || isempty(c), continue; end
    cuts = parseTimes(cutsTable.scene_cuts(c)); bounds = [0, cuts, durations.duration_s(d)]; [shot, index] = max(diff(bounds));
    if shot >= design.secondsPerVideo
        sources = [sources; table(durations.filename(d), category, bounds(index), shot, 'VariableNames', {'filename','category','start_s','longest_clean_shot_s'})]; %#ok<AGROW>
    end
end
end

function values = parseTimes(raw)
if strlength(raw) == 0, values = []; else, values = str2double(split(raw, ';'))'; end
end

function stem = stripExtension(filename)
stem = string(regexprep(filename, '\.[^.]+$', ''));
end
