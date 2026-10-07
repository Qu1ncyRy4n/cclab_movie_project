function report = CHECK_exp00_feasibility()
% CHECK_exp00_feasibility Verify that a future unique-video session is possible.
% Reads MANIFEST.csv, durations.csv, and cuts.csv. It does not need PTB,
% EyeLink, hardware, or the video files themselves.

design = DESIGN_exp00_session();
if mod(design.secondsPerVideo, design.segmentDuration_s) ~= 0
    error('exp00:invalidDesign', 'secondsPerVideo must divide by segmentDuration_s.');
end

here = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(here));
datasetRoot = fullfile(repoRoot, 'video_ebm_dataset');
manifest = readtable(fullfile(datasetRoot, 'MANIFEST.csv'), 'TextType', 'string');
durations = readtable(fullfile(datasetRoot, 'durations.csv'), 'TextType', 'string');
cuts = readtable(fullfile(datasetRoot, 'cuts.csv'), 'TextType', 'string');

manifestStem = stripExtension(manifest.filename);
durationStem = stripExtension(durations.filename);
cutStem = stripExtension(cuts.filename);

nature = eligibleSources(unique(manifestStem(manifest.video_nature == 1)), ...
    durationStem, durations.duration_s, cutStem, cuts.scene_cuts, design);
undirected = eligibleSources(unique(manifestStem(manifest.video_social_undir == 1)), ...
    durationStem, durations.duration_s, cutStem, cuts.scene_cuts, design);
directed = eligibleSources(unique(manifestStem(manifest.video_social_directed == 1)), ...
    durationStem, durations.duration_s, cutStem, cuts.scene_cuts, design);

switch design.socialPool
    case "undir_only"
        social = undirected;
    case "undir_plus_nonaggressive_directed"
        social = [undirected; directed(~contains(lower(directed.stem), design.nonAggressiveDirectedPattern), :)];
    case "all_social"
        social = [undirected; directed];
    otherwise
        error('exp00:unknownSocialPool', 'Unknown socialPool: %s', design.socialPool);
end

trialsPerCondition = design.epochs * design.trialsPerConditionPerEpoch;
requiredNature = trialsPerCondition * 3; % 2 per NN trial + 1 per NS trial
requiredSocial = trialsPerCondition * 3; % 2 per SS trial + 1 per NS trial
transitionsPerTrial = (2 * design.secondsPerVideo / design.segmentDuration_s) - 1;

summary = table( ...
    ["nature"; "social"], ...
    [requiredNature; requiredSocial], ...
    [height(nature); height(social)], ...
    [height(nature) - requiredNature; height(social) - requiredSocial], ...
    'VariableNames', {'category', 'required_unique_sources', 'eligible_sources', 'margin'});

report = struct();
report.design = design;
report.summary = summary;
report.eligibleNature = nature;
report.eligibleSocial = social;
report.trialsPerCondition = trialsPerCondition;
report.totalTrials = trialsPerCondition * numel(design.conditions);
report.transitionsPerTrial = transitionsPerTrial;
report.totalTransitions = report.totalTrials * transitionsPerTrial;
report.transitionsPerCondition = trialsPerCondition * transitionsPerTrial;
report.isFeasible = all(summary.margin >= 0);

fprintf('exp_00 future-session feasibility\n');
fprintf('  epochs: %d; trials/condition/epoch: %d; social pool: %s\n', ...
    design.epochs, design.trialsPerConditionPerEpoch, design.socialPool);
fprintf('  total trials: %d; transitions/trial: %d; total transitions: %d\n', ...
    report.totalTrials, transitionsPerTrial, report.totalTransitions);
disp(summary)
if report.isFeasible
    fprintf('RESULT: feasible with the current policy.\n');
else
    fprintf('RESULT: NOT feasible with the current policy.\n');
end
end

function sources = eligibleSources(stems, durationStem, durationValues, cutStem, cutValues, design)
rows = strings(0, 1);
bestShot = zeros(0, 1);
for i = 1:numel(stems)
    durationIndex = find(durationStem == stems(i), 1);
    cutIndex = find(cutStem == stems(i), 1);
    if isempty(durationIndex) || isempty(cutIndex)
        continue
    end

    duration = durationValues(durationIndex);
    cuts = parseTimes(cutValues(cutIndex));
    longestShot = max(diff([0, cuts, duration]));
    isEligible = duration >= design.secondsPerVideo;
    if design.requireCleanShot
        isEligible = isEligible && longestShot >= design.secondsPerVideo;
    end
    if isEligible
        rows(end + 1, 1) = stems(i); %#ok<AGROW>
        bestShot(end + 1, 1) = longestShot; %#ok<AGROW>
    end
end
sources = table(rows, bestShot, 'VariableNames', {'stem', 'longest_clean_shot_s'});
end

function values = parseTimes(raw)
if strlength(raw) == 0
    values = [];
else
    values = str2double(split(raw, ';'))';
end
end

function stem = stripExtension(filename)
stem = string(regexprep(filename, '\.[^.]+$', ''));
end
