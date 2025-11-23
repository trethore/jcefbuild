@echo off
setlocal EnableExtensions EnableDelayedExpansion

if "%~2"=="" (
    echo "Usage: compile_windows.bat <architecture> <buildType> [<gitrepo> <gitref>]"
    echo ""
    echo "architecture: the target architecture to build for. Architectures are either arm64 or amd64."
    echo "buildType: either Release or Debug"
    echo "gitrepo: git repository url to clone"
    echo "gitref: the git commit id to pull"
    exit /b 1
)

cd /D "%~dp0"

set "ARCH=%~1"
if /I not "%ARCH%"=="amd64" if /I not "%ARCH%"=="arm64" (
    echo "Unsupported architecture %ARCH%. Only amd64 and arm64 are supported."
    exit /b 1
)

:: Determine repository and ref to pull from
if "%~3"=="" (set "REPO=https://github.com/trethore/java-cef.git") else (set "REPO=%~3")
if "%~4"=="" (set "REF=master") else (set "REF=%~4")

:: Execute build with windows Dockerfile (no cache to avoid stale VS/SDK layers)
docker build --no-cache --build-arg TARGETARCH=%ARCH% -t jcefbuild --file docker/DockerfileWindows .
if errorlevel 1 exit /b !ERRORLEVEL!

:: Execute run with windows Dockerfile
if not exist "jcef" mkdir "jcef"
if exist "out" rmdir /S /Q "out"
mkdir "out"
docker rm -f jcefbuild >nul 2>&1
docker run --name jcefbuild -v jcef:"C:\jcef" -e TARGETARCH=%ARCH% -e BUILD_TYPE=%2 -e REPO=%REPO% -e REF=%REF% jcefbuild
if errorlevel 1 exit /b !ERRORLEVEL!
docker cp jcefbuild:/out/binary_distrib.tar.gz out/binary_distrib.tar.gz
if errorlevel 1 exit /b !ERRORLEVEL!
docker rm -f jcefbuild >nul 2>&1
exit /b 0
