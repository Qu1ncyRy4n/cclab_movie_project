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

echo Optional timing benchmarks: Python and MATLAB timing benchmarks (about 5 minutes).
echo Flashing squares appear on the stimulus monitor. That is the test.
echo.
set "RIG_PROFILE=lab_120"
if exist "%ROOT%rig_profile.txt" set /p RIG_PROFILE=<"%ROOT%rig_profile.txt"
set "INPUT="
set /p "INPUT=Rig profile [%RIG_PROFILE%]: "
if not "%INPUT%"=="" set "RIG_PROFILE=%INPUT%"

set "ARCHIVE_ROOT=\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00"
set "INPUT="
set /p "INPUT=Copy results to [%ARCHIVE_ROOT%] (type local to skip): "
if /i "%INPUT%"=="local" (set "ARCHIVE_ROOT=") else if not "%INPUT%"=="" set "ARCHIVE_ROOT=%INPUT%"
set "ARCHIVE_ARG="
if defined ARCHIVE_ROOT set ARCHIVE_ARG=-ArchiveRoot "%ARCHIVE_ROOT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -ComputerProfile "%RIG_PROFILE%" %ARCHIVE_ARG%
set "STATUS=%ERRORLEVEL%"
echo.
if "%STATUS%"=="0" (echo BENCHMARKS DONE.) else (
    echo BENCHMARKS STOPPED. The log is in the newest *_bench folder under %ROOT%data\runs
    echo Do not treat a failed run as timing evidence.
)
pause
exit /b %STATUS%
