function design = DESIGN_exp00_session()
% DESIGN_exp00_session Future full-session settings; not yet used by RUN_exp00_pilot.

design.epochs = 10;
design.trialsPerConditionPerEpoch = 6;
design.conditions = ["NN", "SS", "NS"];
design.segmentDuration_s = 2;
design.secondsPerVideo = 6;
design.requireCleanShot = true;
design.seekSafetyMargin_s = 0.5;
% Manual QC takes precedence over cuts.csv. 00931 has a thermal/color defect
% at onset; the other previously flagged sources may be used only in a plan
% whose exact window has passed manual QC and has been locked.
design.excludedNature = "00931DVD.mp4";
design.excludedSocial = strings(0, 1);
design.excludedSocialPatterns = ["aggression", "mounting"];
design.sourcesPerCategory = 18;
design.repetitionsPerSource = 10;
design.fixedPairsAcrossEpochs = true;
design.mixedOrder = "balanced";
design.maxConditionRun = 2;

% The confirmed interim policy needs only social-undirected sources.
design.socialPool = "undir_only";
design.nonAggressiveDirectedPattern = "aggr";

% Deferred until the standard session flow is complete and validated.
design.overlapFixation.enabled = false;
design.overlapFixation.hold_s = 0.5;
design.overlapFixation.disableAfterConsecutiveFailures = 3;
design.overlapFixation.retryFailedTrial = true;
end
