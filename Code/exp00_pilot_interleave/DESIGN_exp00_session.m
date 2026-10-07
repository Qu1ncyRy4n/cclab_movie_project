function design = DESIGN_exp00_session()
% DESIGN_exp00_session Future full-session settings; not yet used by RUN_exp00_pilot.

design.epochs = 10;
design.trialsPerConditionPerEpoch = 6;
design.conditions = ["NN", "SS", "NS"];
design.segmentDuration_s = 2;
design.secondsPerVideo = 6;
design.requireCleanShot = true;
design.globalUniqueSources = true;
design.mixedOrder = "balanced";

% Candidate policies for the PI decision. The checker reports feasibility for
% the active policy without changing the currently deployed pilot.
design.socialPool = "undir_only";
design.nonAggressiveDirectedPattern = "aggr";

% Deferred until the standard session flow is complete and validated.
design.overlapFixation.enabled = false;
design.overlapFixation.hold_s = 0.5;
design.overlapFixation.disableAfterConsecutiveFailures = 3;
design.overlapFixation.retryFailedTrial = true;
end
