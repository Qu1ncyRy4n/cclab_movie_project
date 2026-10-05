@echo off
setlocal
set "ROOT=%~dp0"
set "RUNNER=%ROOT%cclab_movie_project\run_rig.ps1"
set "BENCH=%ROOT%mat_vs_py_bench"

if not exist "%RUNNER%" (
    echo CCLab rig runner not found: %RUNNER%
    echo Run Install-CCLabRig.ps1 from the package first.
    pause
    exit /b 1
)

set /p "SUBJECT_ID=Subject ID (1-8 letters, numbers, or underscores): "
if "%SUBJECT_ID%"=="" (
    echo A subject ID is required.
    pause
    exit /b 1
)

set /p "RIG_PROFILE=Rig profile [lab_120]: "
if "%RIG_PROFILE%"=="" set "RIG_PROFILE=lab_120"

set /p "ARCHIVE_ROOT=NAS or USB folder for this run (leave blank to keep local only): "
if "%ARCHIVE_ROOT%"=="" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -BenchRoot "%BENCH%" -ComputerProfile "%RIG_PROFILE%" -RunExperiment -SubjectId "%SUBJECT_ID%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%" -BenchRoot "%BENCH%" -ComputerProfile "%RIG_PROFILE%" -RunExperiment -SubjectId "%SUBJECT_ID%" -ArchiveRoot "%ARCHIVE_ROOT%"
)

set "STATUS=%ERRORLEVEL%"
if not "%STATUS%"=="0" (
    echo.
    echo Workflow stopped. The local run folder under C:\CCLabRig\data\runs contains logs and any data collected before the failure.
)
pause
exit /b %STATUS%
