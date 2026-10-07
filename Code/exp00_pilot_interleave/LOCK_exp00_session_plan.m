function approvedPlanFile = LOCK_exp00_session_plan(candidateDir)
% LOCK_exp00_session_plan Approve one visually reviewed 180-trial candidate.
% Run this only after all 36 windows in qc_source_windows.csv have passed QC.
if nargin ~= 1 || ~(ischar(candidateDir) || isstring(candidateDir))
    error('exp00:lockUsage', 'Usage: LOCK_exp00_session_plan(candidateOutputFolder)');
end
candidateDir = char(candidateDir);
planFile = fullfile(candidateDir, 'session_plan.csv');
qcFile = fullfile(candidateDir, 'qc_source_windows.csv');
if exist(planFile, 'file') ~= 2 || exist(qcFile, 'file') ~= 2
    error('exp00:lockInput', 'Candidate folder must contain session_plan.csv and qc_source_windows.csv.');
end

plan = readtable(planFile, 'TextType', 'string');
required = {'Epoch','TrialInEpoch','TrialNum','Condition','PairID','PairRepetition', ...
    'VideoA','VideoB','CategoryA','CategoryB','StartA_s','StartB_s'};
if height(plan) ~= 180 || ~all(ismember(required, plan.Properties.VariableNames))
    error('exp00:lockPlan', 'Candidate is not a valid 180-trial exp_00 plan.');
end
if any(countcats(categorical(string(plan.Condition), ["NN","SS","NS"])) ~= 60)
    error('exp00:lockConditions', 'Candidate must have 60 trials of each condition.');
end
if numel(unique(string(plan.PairID))) ~= 18 || any(countcats(categorical(string(plan.PairID))) ~= 10)
    error('exp00:lockPairs', 'Candidate must contain 18 fixed pairs repeated ten times.');
end

design = DESIGN_exp00_session();
allVideos = [string(plan.VideoA); string(plan.VideoB)];
if any(ismember(allVideos, design.excludedNature)) || ...
        any(contains(lower(allVideos), design.excludedSocialPatterns))
    error('exp00:lockExcluded', 'Candidate contains a permanently excluded source. Generate a replacement candidate.');
end

qc = readtable(qcFile, 'TextType', 'string');
if height(qc) ~= 36 || ~all(ismember({'Video','Category','Start_s','End_s'}, qc.Properties.VariableNames))
    error('exp00:lockQC', 'Candidate QC sheet must contain exactly 36 source windows.');
end
candidateSources = unique([string(plan.VideoA); string(plan.VideoB)]);
if ~isequal(sort(candidateSources), sort(string(qc.Video)))
    error('exp00:lockQC', 'QC sheet does not match the plan sources.');
end

approvedPlanFile = fullfile(fileparts(mfilename('fullpath')), 'approved_session_plan.csv');
if exist(approvedPlanFile, 'file') == 2
    error('exp00:lockExists', 'An approved plan already exists. Rename or archive it before locking another plan.');
end
copyfile(planFile, approvedPlanFile);
fprintf('Locked approved exp_00 plan: %s\n', approvedPlanFile);
end
