@echo off
setlocal
set "ROOT=%~dp0"
set "SYNC=%ROOT%cclab_movie_project\sync_data.ps1"
if not exist "%SYNC%" (
    echo Data sync script not found: %SYNC%
    pause
    exit /b 1
)

echo Copy completed local runs to an archive after a NAS outage.
echo This only copies data. It never deletes the local run folder.
set "SESSION_ID="
set /p "SESSION_ID=Run folder name, or ALL to sync every local run: "
if "%SESSION_ID%"=="" (
    echo A run folder name or ALL is required.
    pause
    exit /b 1
)

set "ARCHIVE_ROOT=\\cns-nas.ucdavis.edu\cclab\shared\experiment_packages\runs\exp00"
set "INPUT="
set /p "INPUT=Archive destination [%ARCHIVE_ROOT%]: "
if not "%INPUT%"=="" set "ARCHIVE_ROOT=%INPUT%"

if /i "%SESSION_ID%"=="ALL" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SYNC%" -All -ArchiveRoot "%ARCHIVE_ROOT%"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SYNC%" -SessionId "%SESSION_ID%" -ArchiveRoot "%ARCHIVE_ROOT%"
)
set "STATUS=%ERRORLEVEL%"
pause
exit /b %STATUS%
