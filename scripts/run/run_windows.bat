@echo off

setlocal

set "VCVARS_BAT="
set "NATIVE_JAVA_HOME_DIR="
set "TOOLS_JAVA_HOME_DIR="
set "DISTRIB_DIR="

echo Building 64-bit version

if "%TARGETARCH%"=="amd64" (
    set "VCVARS_BAT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    set "NATIVE_JAVA_HOME_DIR=C:/jdk-17"
    set "TOOLS_JAVA_HOME_DIR=C:/jdk-17"
    set "DISTRIB_DIR=win64"
)
if "%TARGETARCH%"=="arm64" (
    set "VCVARS_BAT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsamd64_arm64.bat"
    set "NATIVE_JAVA_HOME_DIR=C:/jdk-17-arm64"
    set "TOOLS_JAVA_HOME_DIR=C:/jdk-17"
    set "DISTRIB_DIR=win64"
)

if not defined VCVARS_BAT (
    echo ERROR: Unsupported TARGETARCH "%TARGETARCH%"
    exit /b 1
)

if exist "%VCVARS_BAT%" goto :VCVARS_READY
echo ERROR: Required Visual Studio environment script not found: %VCVARS_BAT%
exit /b 1

:VCVARS_READY

:: Update ssl certs
certutil -generateSSTFromWU roots.sst && certutil -addstore -f root roots.sst && del roots.sst
if errorlevel 1 exit /b %errorlevel%

:: Check residency of workdir
cd ..
if errorlevel 1 exit /b %errorlevel%
if exist "jcef\README.md" (echo "Found existing files to build" && cd jcef) ^
else (echo "Did not find files to build - cloning..." && GOTO :CLONE)
if errorlevel 1 exit /b %errorlevel%

:BUILD
:: CMakeLists patching 
python C:/patch_cmake.py CMakeLists.txt C:/CMakeLists.txt.patch
if errorlevel 1 exit /b %errorlevel%

:: Prepare build dir
if not exist jcef_build mkdir jcef_build
if errorlevel 1 exit /b %errorlevel%
cd jcef_build
if errorlevel 1 exit /b %errorlevel%

:: Load vcvars for the selected build
call "%VCVARS_BAT%"
if errorlevel 1 exit /b %errorlevel%

set "JAVA_HOME=%NATIVE_JAVA_HOME_DIR%"
set "PATH=%JAVA_HOME%/bin;%PATH%"

:: Perform build
cmake -G "Ninja" -DJAVA_HOME="%NATIVE_JAVA_HOME_DIR%" -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ..
if errorlevel 1 exit /b %errorlevel%
ninja -j4
if errorlevel 1 exit /b %errorlevel%

:: Compile java classes
cd ../tools
if errorlevel 1 exit /b %errorlevel%
set "JAVA_HOME=%TOOLS_JAVA_HOME_DIR%"
set "PATH=%JAVA_HOME%/bin;%PATH%"
call compile.bat %DISTRIB_DIR%
if errorlevel 1 exit /b %errorlevel%

:: Create distribution
call make_distrib.bat %DISTRIB_DIR%
if errorlevel 1 exit /b %errorlevel%

:: Go to results
cd ../binary_distrib/%DISTRIB_DIR%
if errorlevel 1 exit /b %errorlevel%
:: Zip results to C:\out
del /F C:\out\binary_distrib.tar.gz 2>nul
if not exist "C:\out" mkdir "C:\out"
if errorlevel 1 exit /b %errorlevel%
tar -czvf C:\out\binary_distrib.tar.gz *
if errorlevel 1 exit /b %errorlevel%

GOTO :EOF



:CLONE
if exist jcef rmdir /S /Q jcef
if errorlevel 1 exit /b %errorlevel%
git clone %REPO% jcef
if errorlevel 1 exit /b %errorlevel%
cd jcef
if errorlevel 1 exit /b %errorlevel%
git checkout %REF%
if errorlevel 1 exit /b %errorlevel%
GOTO :BUILD
