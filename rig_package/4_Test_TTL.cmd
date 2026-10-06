@echo off
setlocal
set "ROOT=%~dp0"
set "TEST_DIR=%ROOT%cclab_movie_project\Code\exp00_pilot_interleave"
if not exist "%TEST_DIR%\TEST_exp00_TTL.m" (
    echo TTL test script not found: %TEST_DIR%\TEST_exp00_TTL.m
    pause
    exit /b 1
)

echo Start recording on the downstream system now.
echo This test sends five 100 ms pulses on A, then five on B.
echo.
pushd "%TEST_DIR%"
matlab.exe -batch "TEST_exp00_TTL"
set "STATUS=%ERRORLEVEL%"
popd

set "DIAGNOSTIC_ROOT=%ROOT%data\ttl_diagnostics"
set "ARCHIVE_ROOT=\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00\ttl_diagnostics"
if exist "%DIAGNOSTIC_ROOT%" (
    robocopy "%DIAGNOSTIC_ROOT%" "%ARCHIVE_ROOT%" /E /Z /R:3 /W:5 /COPY:DAT
    if %ERRORLEVEL% LEQ 7 (echo TTL diagnostic archived to %ARCHIVE_ROOT%) else echo TTL diagnostic archive failed.
)
pause
exit /b %STATUS%
