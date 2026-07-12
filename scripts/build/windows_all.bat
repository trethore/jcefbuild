@echo off

setlocal EnableExtensions

if "%~1"=="" (
    echo Usage: scripts\build\windows_all.bat ^<buildType^> [^<gitrepo^> ^<gitref^>]
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "ROOT_DIR=%%~fI"

set "JCEF_WORK_DIR=%ROOT_DIR%\jcef-windows-amd64"
set "JCEF_OUTPUT_DIR=out\windows-amd64"
set "JCEF_DOCKER_CONTAINER=jcefbuild-amd64"
set "JCEF_SKIP_DOCKER_BUILD="
call "%SCRIPT_DIR%windows.bat" amd64 "%~1" "%~2" "%~3"
if errorlevel 1 exit /b %errorlevel%

set "JCEF_WORK_DIR=%ROOT_DIR%\jcef-windows-arm64"
set "JCEF_OUTPUT_DIR=out\windows-arm64"
set "JCEF_DOCKER_CONTAINER=jcefbuild-arm64"
set "JCEF_SKIP_DOCKER_BUILD=1"
call "%SCRIPT_DIR%windows.bat" arm64 "%~1" "%~2" "%~3"
if errorlevel 1 exit /b %errorlevel%

exit /b 0
