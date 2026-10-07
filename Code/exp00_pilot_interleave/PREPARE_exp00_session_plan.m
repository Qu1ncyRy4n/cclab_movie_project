function [plan, metadata] = PREPARE_exp00_session_plan(outputDir)
% PREPARE_exp00_session_plan Generate and save the reproducible session plan.
% Run once at session start, before launching the future full-session task.
if nargin < 1 || isempty(outputDir)
    outputDir = fullfile(pwd, 'Output_exp00_session_plan', datestr(now, 'yyyy-mm-dd_HHMMSS'));
end
if exist(outputDir, 'dir')
    error('exp00:planOutputExists', 'Plan output directory already exists: %s', outputDir);
end
mkdir(outputDir);

[plan, metadata] = BUILD_exp00_session_plan();
writetable(plan, fullfile(outputDir, 'session_plan.csv'));
save(fullfile(outputDir, 'session_plan.mat'), 'plan', 'metadata');

sourceA = table(plan.VideoA, plan.CategoryA, plan.StartA_s, ...
    'VariableNames', {'Video','Category','Start_s'});
sourceB = table(plan.VideoB, plan.CategoryB, plan.StartB_s, ...
    'VariableNames', {'Video','Category','Start_s'});
qcSources = unique([sourceA; sourceB], 'rows', 'stable');
qcSources.End_s = qcSources.Start_s + metadata.design.secondsPerVideo;
qcSources = sortrows(qcSources, {'Category','Video'});
writetable(qcSources, fullfile(outputDir, 'qc_source_windows.csv'));

qcPairs = plan(plan.PairRepetition == 1, {'PairID','Condition','VideoA','StartA_s','VideoB','StartB_s'});
qcPairs.EndA_s = qcPairs.StartA_s + metadata.design.secondsPerVideo;
qcPairs.EndB_s = qcPairs.StartB_s + metadata.design.secondsPerVideo;
writetable(qcPairs, fullfile(outputDir, 'qc_fixed_pairs.csv'));

fid = fopen(fullfile(outputDir, 'session_plan_metadata.json'), 'w');
if fid < 0, error('exp00:planMetadata', 'Cannot write plan metadata.'); end
cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
jsonMetadata = rmfield(metadata, {'natureSources', 'socialSources'});
fprintf(fid, '%s\n', jsonencode(jsonMetadata));

fprintf('Prepared exp_00 plan: %s\n', outputDir);
fprintf('Timestamp seed: %s; MATLAB RNG seed: %u\n', metadata.timestampSeed, metadata.rngSeed);
fprintf('QC source windows: %s\n', fullfile(outputDir, 'qc_source_windows.csv'));
fprintf('QC fixed pairs: %s\n', fullfile(outputDir, 'qc_fixed_pairs.csv'));
end
