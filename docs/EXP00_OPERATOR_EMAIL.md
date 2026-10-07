# exp_00 Operator Run Script

Use this text as the operator email/run sheet. The experiment always writes a complete local run folder first. NAS copying is a second, non-destructive step.

## Before The Session

1. Confirm the participant is `Vennie`, `Isaac`, or `DEV-00`.
2. Confirm the experimenter/developer name to record.
3. The installer defaults to `Desktop\Video_Proj_exp-00`; its `video_folder.txt` defaults to `%USERPROFILE%\Desktop\video_ebm_dataset`. Confirm that local video copy exists and run `1_Setup_Rig.cmd` if it does not.
4. Use `3_Test_TTL.cmd` if TTL wiring has changed or has not been checked that day.
5. Choose reward pump-on duration. Default is 400 ms; normal range is 300-500 ms.
6. Confirm with the PI whether the social-video pool can include manually reviewed directed clips. The current 10-epoch unique-video design is infeasible with social-undirected clips alone.

## Start The Task

1. Run `2_Run_Experiment.cmd`.
2. Enter participant, experimenter/developer, rig profile, eye-tracking mode, neural-I/O mode, reward duration, and archive destination in the Command Prompt.
3. MATLAB starts with cleared variables/functions and prints the participant, operator, reward duration, and controls before opening the task window.
4. Verify the Command Prompt transcript is being written under the local run folder.

## During The Task

1. Up Arrow: pause.
2. During fixation, Up Arrow pauses immediately and preserves the active trial number.
3. During movie/reward/ITI, Up Arrow requests a safe pause. The current trial finishes and saves; the task pauses before the next unused trial number.
4. Down Arrow: resume the paused fixation or begin the displayed next trial.
5. F during a movie: immediately stop the current movie trial. It is saved as `ForcedPause`, completes its blank ITI, then pauses before the next unused trial number.
6. ESC: shows red `?!` for three seconds. Press ESC again during that window to exit. Let the window expire to continue.
7. Do not restart MATLAB to pause. Doing so risks an incomplete EyeLink/TTL record; use Up/Down Arrow or F instead.
8. With neural I/O enabled, pause and resume emit 50 ms control TTLs: `C` (pause, Dev2/port0/line5) and `D` (resume, Dev2/port0/line7). Verify C/D in `3_Test_TTL.cmd` before recording a new acquisition setup.

## After The Task

1. Confirm MATLAB reports the local run folder.
2. Confirm the run contains `experiment/`, `logs/`, `run_metadata.json`, and the experiment output folder with MAT, CSV event log, and EDF when EyeLink was enabled.
3. If NAS copy succeeded, confirm the matching archive folder exists.
4. If NAS is unavailable, leave the local run untouched. When the NAS returns, run `5_Sync_Data.cmd`, enter the run-folder name, and copy it to the archive. The sync command never deletes local data.

## Remote Dummy-Machine Test

1. Use profile `win_dummy`.
2. Set Eye Tracking `off` and Neural I/O `off`.
3. Set a local video root containing `video_all/` and the pilot pool files.
4. Run `run_rig.ps1 -ComputerProfile win_dummy -RunExperiment -SkipBench -SubjectId DEV-00 -Experimenter <name> -EyeTracking off -NeuralIO off`.
5. Test CLI startup, fixation with mouse-as-gaze, Up/Down pause behavior, double-ESC exit, event log creation, and local output. This does not validate EyeLink, reward, TTL, or neural acquisition.
