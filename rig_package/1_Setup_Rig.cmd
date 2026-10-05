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

echo Step 1 of 3: copy the pilot videos locally, install the Python environment,
echo check the rig hardware, and check MATLAB can see all pilot videos.
echo.
set "RIG_PROFILE=lab_120"
if exist "%ROOT%rig_profile.txt" set /p RIG_PROFILE=<"%ROOT%rig_profile.txt"
set "INPUT="
set /p "INPUT=Rig profile (lab_120, lab_121, or win_dummy on a test PC) [%RIG_PROFILE%]: "
if not "%INPUT%"=="" set "RIG_PROFILE=%INPUT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -ComputerProfile "%RIG_PROFILE%" -Setup
set "STATUS=%ERRORLEVEL%"
echo.
if "%STATUS%"=="0" (
    >"%ROOT%rig_profile.txt" echo(%RIG_PROFILE%
    echo SETUP OK. Rig profile %RIG_PROFILE% saved for steps 2 and 3.
) else (
    echo SETUP FAILED. Fix the error above, then run this again.
    echo The log is in the newest *_setup folder under %ROOT%data\runs
)
pause
exit /b %STATUS%
