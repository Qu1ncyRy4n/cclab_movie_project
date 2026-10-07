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

fid = fopen(fullfile(outputDir, 'session_plan_metadata.json'), 'w');
if fid < 0, error('exp00:planMetadata', 'Cannot write plan metadata.'); end
cleanupFile = onCleanup(@() fclose(fid)); %#ok<NASGU>
jsonMetadata = rmfield(metadata, {'natureSources', 'socialSources'});
fprintf(fid, '%s\n', jsonencode(jsonMetadata));

fprintf('Prepared exp_00 plan: %s\n', outputDir);
fprintf('Timestamp seed: %s; MATLAB RNG seed: %u\n', metadata.timestampSeed, metadata.rngSeed);
end
