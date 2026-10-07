@echo off
setlocal
set "ROOT=%~dp0"
set "RUNNER=%ROOT%cclab_movie_project\run_rig.ps1"
if not exist "%RUNNER%" (
    echo CCLab rig runner not found: %RUNNER%
    echo Run Install-CCLabRig.ps1 from the package first.
    pause
    exit /b 1
)

echo Step 3 of 3: exp_00 pilot. Up Arrow safe-pause, Down Arrow resume, F abort-and-pause, ESC then ESC again within 3s quits.
echo.
set "SUBJECT_ID="
set /p "SUBJECT_ID=Participant (Vennie, Isaac, or DEV-00): "
if "%SUBJECT_ID%"=="" (
    echo A subject ID is required.
    pause
    exit /b 1
)

set "EXPERIMENTER="
set /p "EXPERIMENTER=Experimenter/developer name: "
if "%EXPERIMENTER%"=="" (
    echo An experimenter/developer name is required.
    pause
    exit /b 1
)

set "RIG_PROFILE=lab_120"
if exist "%ROOT%rig_profile.txt" set /p RIG_PROFILE=<"%ROOT%rig_profile.txt"
set "INPUT="
echo Available rig profiles: lab_120, lab_121, win_dummy, dev_wsl
set /p "INPUT=Rig profile [%RIG_PROFILE%]: "
if not "%INPUT%"=="" set "RIG_PROFILE=%INPUT%"
if /i not "%RIG_PROFILE%"=="lab_120" if /i not "%RIG_PROFILE%"=="lab_121" if /i not "%RIG_PROFILE%"=="win_dummy" if /i not "%RIG_PROFILE%"=="dev_wsl" (
    echo Invalid rig profile. Choose lab_120, lab_121, win_dummy, or dev_wsl.
    pause
    exit /b 1
)

set "EYE_TRACKING=auto"
set /p "INPUT=Eye tracking [%EYE_TRACKING%] (auto/on/off): "
if not "%INPUT%"=="" set "EYE_TRACKING=%INPUT%"
set "NEURAL_IO=auto"
set /p "INPUT=Neural I/O and reward [%NEURAL_IO%] (auto/on/off): "
if not "%INPUT%"=="" set "NEURAL_IO=%INPUT%"

set "REWARD_MS=400"
set /p "INPUT=Reward pump-on duration in ms [%REWARD_MS%] (usually 300-500): "
if not "%INPUT%"=="" set "REWARD_MS=%INPUT%"

set "ARCHIVE_ROOT=\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00"
set "INPUT="
set /p "INPUT=Copy results to [%ARCHIVE_ROOT%] (type local to skip): "
if /i "%INPUT%"=="local" (set "ARCHIVE_ROOT=") else if not "%INPUT%"=="" set "ARCHIVE_ROOT=%INPUT%"
set "ARCHIVE_ARG="
if defined ARCHIVE_ROOT set ARCHIVE_ARG=-ArchiveRoot "%ARCHIVE_ROOT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -ComputerProfile "%RIG_PROFILE%" -EyeTracking "%EYE_TRACKING%" -NeuralIO "%NEURAL_IO%" -RewardMs "%REWARD_MS%" -RunExperiment -SkipBench -SubjectId "%SUBJECT_ID%" -Experimenter "%EXPERIMENTER%" %ARCHIVE_ARG%
set "STATUS=%ERRORLEVEL%"
echo.
if "%STATUS%"=="0" (echo EXPERIMENT DONE.) else (
    echo EXPERIMENT STOPPED. Partial data and logs are in the newest *_exp folder under %ROOT%data\runs
)
pause
exit /b %STATUS%
