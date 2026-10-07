@echo off
setlocal
rem Double-click from the package folder on the NAS. (Windows may print
rem "UNC paths are not supported" first; that message is harmless.)
set "PKG=%~dp0"
echo Install the exp_00 rig code from this package onto this computer's local disk.
echo Reinstalling over an existing install keeps its data\runs folder.
echo.
set "INSTALL_ROOT=desktop"
set "INPUT="
set /p "INPUT=Install to [%INSTALL_ROOT%] (Desktop\Video_Proj_exp-00): "
if not "%INPUT%"=="" set "INSTALL_ROOT=%INPUT%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PKG%Install-CCLabRig.ps1" -InstallRoot "%INSTALL_ROOT%" -OpenFolder
set "STATUS=%ERRORLEVEL%"
echo.
if "%STATUS%"=="0" (echo INSTALL OK. Next: double-click 1_Setup_Rig.cmd in the folder that just opened.) else (echo INSTALL FAILED. Read the error above.)
pause
exit /b %STATUS%
