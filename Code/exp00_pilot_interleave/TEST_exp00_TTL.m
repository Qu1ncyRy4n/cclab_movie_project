function TEST_exp00_TTL()
% Emit visible, non-reward TTL test pulses on the two exp_00 marker lines.
% Start the external recorder first. A is Dev2/port0/line4; B is line3.

codeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(codeRoot));

fprintf('TTL test starts in 3 seconds. Start external recording now.\n');
WaitSecs(3);
cclabInitDIO('rig-right');
cleanupDio = onCleanup(@cclabCloseDIO); %#ok<NASGU>

for channel = ['A', 'B']
    fprintf('Testing TTL %s: five 100 ms pulses, one second apart.\n', channel);
    for pulseNumber = 1:5
        fprintf('TTL %s pulse %d/5 sent.\n', channel, pulseNumber);
        cclabPulse(channel, 100);
        WaitSecs(0.9);
    end
end

fprintf('TTL test complete.\n');
end
