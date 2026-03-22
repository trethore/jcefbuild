@echo off

setlocal EnableExtensions EnableDelayedExpansion

if ("%2"=="") ( ^ 
    echo "Usage: scripts\compile\compile_windows.bat <architecture> <buildType> [<gitrepo> <gitref>]" && ^ 
    echo "" && ^ 
    echo "architecture: the target architecture to build for. Architectures are either arm64 or amd64." && ^ 
    echo "buildType: either Release or Debug" && ^ 
    echo "gitrepo: git repository url to clone" && ^ 
    echo "gitref: the git commit id to pull" && ^ 
    exit /b 1 ^ 
)

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "ROOT_DIR=%%~fI"
set "TARGETARCH=%~1"
set "BUILD_TYPE=%~2"
set "DEFAULT_REPO=https://github.com/trethore/jcef.git"
set "DEFAULT_REF=master"
set "DOCKERFILE=scripts\docker\DockerfileWindows"
set "DOCKER_IMAGE=jcefbuild"
set "DOCKER_CONTAINER=jcefbuild"
set "OUT_DIR=out"
set "JCEF_DIR=jcef"
set "BINARY_DISTRIB_ARCHIVE=%OUT_DIR%\binary_distrib.tar.gz"
set "ENSURE_DOCKER_SCRIPT=%ROOT_DIR%\scripts\windows\ensure_docker.ps1"

cd /D "%ROOT_DIR%"

::Determine repository and ref to pull from
if "%~3"=="" (set "REPO=%DEFAULT_REPO%") else (set "REPO=%~3")
if "%~4"=="" (set "REF=%DEFAULT_REF%") else (set "REF=%~4")

if /I not "%TARGETARCH%"=="amd64" if /I not "%TARGETARCH%"=="arm64" (
    echo ERROR: Unsupported architecture "%TARGETARCH%". Supported architectures are amd64 and arm64.
    exit /b 1
)

call :ENSURE_DOCKER
if errorlevel 1 exit /b %errorlevel%

:: Execute build with windows Dockerfile
docker build ^
    -m 4GB ^
    -t "%DOCKER_IMAGE%" ^
    --build-arg TARGETARCH=%TARGETARCH% ^
    --file "%DOCKERFILE%" ^
    .
if errorlevel 1 exit /b %errorlevel%

:: Execute run with windows Dockerfile
if not exist "%JCEF_DIR%" mkdir "%JCEF_DIR%"
rmdir /S /Q out 2>nul
mkdir "%OUT_DIR%"
docker rm -f "%DOCKER_CONTAINER%" >nul 2>&1
docker run ^
    --name "%DOCKER_CONTAINER%" ^
    -v jcef:"C:\jcef" ^
    -e TARGETARCH=%TARGETARCH% ^
    -e BUILD_TYPE=%BUILD_TYPE% ^
    -e REPO=%REPO% ^
    -e REF=%REF% ^
    "%DOCKER_IMAGE%"
if errorlevel 1 exit /b %errorlevel%
docker cp %DOCKER_CONTAINER%:C:\out\binary_distrib.tar.gz "%BINARY_DISTRIB_ARCHIVE%"
if errorlevel 1 exit /b %errorlevel%
docker rm "%DOCKER_CONTAINER%" >nul 2>&1
if not exist "%BINARY_DISTRIB_ARCHIVE%" (
    echo ERROR: %BINARY_DISTRIB_ARCHIVE% not found after build.
    exit /b 1
)

goto :EOF

:ENSURE_DOCKER
echo Ensuring Docker daemon is available...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ENSURE_DOCKER_SCRIPT%"
exit /b %errorlevel%
