@echo off

setlocal

if ("%2"=="") ( ^ 
    echo "Usage: scripts\compile\compile_windows.bat <architecture> <buildType> [<gitrepo> <gitref>]" && ^ 
    echo "" && ^ 
    echo "architecture: the target architecture to build for. Architectures are either arm64, 386 or amd64." && ^ 
    echo "buildType: either Release or Debug" && ^ 
    echo "gitrepo: git repository url to clone" && ^ 
    echo "gitref: the git commit id to pull" && ^ 
    exit /b 1 ^ 
)

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "ROOT_DIR=%%~fI"

cd /D "%ROOT_DIR%"

::Determine repository and ref to pull from
if ("%3"=="") (set "REPO=https://bitbucket.org/chromiumembedded/java-cef.git") ^
else (set "REPO=%3")
if ("%4"=="") (set "REF=master") ^
else (set "REF=%4")

call :ENSURE_DOCKER
if errorlevel 1 exit /b %errorlevel%

:: Execute build with windows Dockerfile
docker build -m 4GB -t jcefbuild --build-arg TARGETARCH=%1 --file scripts/docker/DockerfileWindows .
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

goto :EOF

:ENSURE_DOCKER
echo Ensuring Docker daemon is available...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$serviceNames = @('docker', 'com.docker.service'); $services = @(); foreach ($name in $serviceNames) { $svc = Get-Service -Name $name -ErrorAction SilentlyContinue; if ($svc) { $services += $svc } }; foreach ($svc in $services) { if ($svc.Status -ne 'Running') { Write-Host ('Starting service ' + $svc.Name + '...'); Start-Service -Name $svc.Name -ErrorAction SilentlyContinue } }; $deadline = (Get-Date).AddMinutes(3); while ((Get-Date) -lt $deadline) { docker version *> $null; if ($LASTEXITCODE -eq 0) { Write-Host 'Docker daemon is ready.'; exit 0 }; foreach ($svc in $services) { try { $svc.Refresh(); if ($svc.Status -ne 'Running') { Start-Service -Name $svc.Name -ErrorAction SilentlyContinue } } catch { } }; Start-Sleep -Seconds 5 }; Write-Error 'Docker daemon did not become available in time.'; docker version; exit 1"
exit /b %errorlevel%
