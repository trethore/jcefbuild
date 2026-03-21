@echo off

setlocal

if ("%2"=="") ( ^ 
    echo "Usage: compile_windows.bat <architecture> <buildType> [<gitrepo> <gitref>]" && ^ 
    echo "" && ^ 
    echo "architecture: the target architecture to build for. Architectures are either arm64, 386 or amd64." && ^ 
    echo "buildType: either Release or Debug" && ^ 
    echo "gitrepo: git repository url to clone" && ^ 
    echo "gitref: the git commit id to pull" && ^ 
    exit 1 ^ 
)

cd /D "%~dp0"

::Determine repository and ref to pull from
if ("%3"=="") (set "REPO=https://bitbucket.org/chromiumembedded/java-cef.git") ^
else (set "REPO=%3")
if ("%4"=="") (set "REF=master") ^
else (set "REF=%4")

:: Execute build with windows Dockerfile
docker build -t jcefbuild --file DockerfileWindows .
if errorlevel 1 exit /b %errorlevel%

:: Execute run with windows Dockerfile
if not exist "jcef" mkdir "jcef"
rmdir /S /Q out 2>nul
mkdir "out"
docker rm -f jcefbuild >nul 2>&1
docker run --name jcefbuild -v jcef:"C:\jcef" -e TARGETARCH=%1 -e BUILD_TYPE=%2 -e REPO=%REPO% -e REF=%REF% jcefbuild
if errorlevel 1 exit /b %errorlevel%
docker cp jcefbuild:C:\out\binary_distrib.tar.gz out\binary_distrib.tar.gz
if errorlevel 1 exit /b %errorlevel%
docker rm jcefbuild >nul 2>&1
if not exist "out\binary_distrib.tar.gz" (
    echo ERROR: out\binary_distrib.tar.gz not found after build.
    exit /b 1
)
