function TEST_exp00_TTL()
% Emit visible, non-reward TTL test pulses and preserve rig configuration.
% Start the external recorder first. A is Dev2/port0/line4; B is line3.

codeRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(codeRoot));
rigRoot = fileparts(fileparts(codeRoot));
logDir = fullfile(rigRoot, 'data', 'ttl_diagnostics');
if ~exist(logDir, 'dir'), mkdir(logDir); end
logPath = fullfile(logDir, ['ttl_test_' datestr(now, 'yyyymmdd_HHMMSS') '.txt']);
diary(logPath);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('CCLab TTL diagnostic\n');
fprintf('Started: %s\n', datestr(now, 31));
fprintf('Computer: %s\n', getenv('COMPUTERNAME'));
fprintf('Config: %s\n\n', fullfile(codeRoot, 'cclab-matlab-tools', 'cfg', 'rig-right.txt'));
fprintf('Configured mapping:\n');
type(fullfile(codeRoot, 'cclab-matlab-tools', 'cfg', 'rig-right.txt'));
fprintf('\nDetected DAQ devices:\n');
disp(daqlist());

fprintf('\nTTL test starts in 3 seconds. Start external recording now.\n');
WaitSecs(3);
cclabInitDIO('rig-right');
cleanupDio = onCleanup(@cclabCloseDIO); %#ok<NASGU>

global g_dio;
fprintf('\nConfigured digital-output channels:\n');
disp(g_dio.digout.daq.Channels);

for channel = ['A', 'B']
    fprintf('Testing TTL %s: five 100 ms pulses, one second apart.\n', channel);
    for pulseNumber = 1:5
        fprintf('TTL %s pulse %d/5 sent at %s.\n', channel, pulseNumber, datestr(now, 31));
        cclabPulse(channel, 100);
        WaitSecs(0.9);
    end
end

fprintf('TTL test complete. Diagnostic log: %s\n', logPath);
end
