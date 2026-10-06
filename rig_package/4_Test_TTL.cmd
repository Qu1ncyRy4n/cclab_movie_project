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
pause
exit /b %STATUS%
