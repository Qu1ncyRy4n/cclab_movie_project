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

echo Step 3 of 3: exp_00 pilot. Keys: ESC quit, PageUp pause, PageDown resume.
echo.
set "SUBJECT_ID="
set /p "SUBJECT_ID=Subject ID (1-8 letters, numbers, or underscores): "
if "%SUBJECT_ID%"=="" (
    echo A subject ID is required.
    pause
    exit /b 1
)

set "RIG_PROFILE=lab_120"
if exist "%ROOT%rig_profile.txt" set /p RIG_PROFILE=<"%ROOT%rig_profile.txt"
set "INPUT="
set /p "INPUT=Rig profile [%RIG_PROFILE%]: "
if not "%INPUT%"=="" set "RIG_PROFILE=%INPUT%"

set "EYE_TRACKING=auto"
set /p "INPUT=Eye tracking [%EYE_TRACKING%] (auto/on/off): "
if not "%INPUT%"=="" set "EYE_TRACKING=%INPUT%"
set "NEURAL_IO=auto"
set /p "INPUT=Neural I/O and reward [%NEURAL_IO%] (auto/on/off): "
if not "%INPUT%"=="" set "NEURAL_IO=%INPUT%"

set "ARCHIVE_ROOT=\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00"
set "INPUT="
set /p "INPUT=Copy results to [%ARCHIVE_ROOT%] (type local to skip): "
if /i "%INPUT%"=="local" (set "ARCHIVE_ROOT=") else if not "%INPUT%"=="" set "ARCHIVE_ROOT=%INPUT%"
set "ARCHIVE_ARG="
if defined ARCHIVE_ROOT set ARCHIVE_ARG=-ArchiveRoot "%ARCHIVE_ROOT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -ComputerProfile "%RIG_PROFILE%" -EyeTracking "%EYE_TRACKING%" -NeuralIO "%NEURAL_IO%" -RunExperiment -SkipBench -SubjectId "%SUBJECT_ID%" %ARCHIVE_ARG%
set "STATUS=%ERRORLEVEL%"
echo.
if "%STATUS%"=="0" (echo EXPERIMENT DONE.) else (
    echo EXPERIMENT STOPPED. Partial data and logs are in the newest *_exp folder under %ROOT%data\runs
)
pause
exit /b %STATUS%
