@echo off

setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=C:\"
set "JCEF_DIR=C:\jcef"
set "PATCH_SCRIPT=C:\patch_cmake.py"
set "PATCH_FILE=C:\CMakeLists.txt.patch"
set "OUT_DIR=C:\out"
set "BINARY_DISTRIB_ARCHIVE=%OUT_DIR%\binary_distrib.tar.gz"
set "VCVARS_BAT="
set "NATIVE_JAVA_HOME_DIR="
set "TOOLS_JAVA_HOME_DIR="
set "DISTRIB_DIR="

set "TARGETARCH=%TARGETARCH%"
set "BUILD_TYPE=%BUILD_TYPE%"

echo Building 64-bit version

call :SET_ARCH_CONFIG || exit /b !errorlevel!

if exist "%VCVARS_BAT%" goto :VCVARS_READY
echo ERROR: Required Visual Studio environment script not found: %VCVARS_BAT%
exit /b 1

:VCVARS_READY

:: Update ssl certs
certutil -generateSSTFromWU roots.sst ^
    && certutil -addstore -f root roots.sst ^
    && del roots.sst ^
    || exit /b !errorlevel!

:: Prepare the requested checkout. C:\jcef is bind-mounted from the host so
:: local sources and downloaded build dependencies are preserved.
cd /D "%ROOT_DIR%" || exit /b !errorlevel!
call :ENSURE_CHECKOUT || exit /b !errorlevel!

:: CMakeLists patching 
python "%PATCH_SCRIPT%" CMakeLists.txt "%PATCH_FILE%" || exit /b !errorlevel!

:: Prepare build dir
if not exist jcef_build mkdir jcef_build
cd /D jcef_build || exit /b !errorlevel!

:: Load vcvars for the selected build
call "%VCVARS_BAT%" || exit /b !errorlevel!

call :SET_JAVA_ENV "%NATIVE_JAVA_HOME_DIR%"

:: Perform build
cmake ^
    -G "Ninja" ^
    -DJAVA_HOME="%NATIVE_JAVA_HOME_DIR%" ^
    -DCMAKE_MSVC_RUNTIME_LIBRARY= ^
    -DCMAKE_BUILD_TYPE=%BUILD_TYPE% ^
    .. || exit /b !errorlevel!
ninja -j4 || exit /b !errorlevel!

:: Compile java classes
cd /D ..\tools || exit /b !errorlevel!
call :SET_JAVA_ENV "%TOOLS_JAVA_HOME_DIR%"
call compile.bat %DISTRIB_DIR% || exit /b !errorlevel!

:: Create distribution
call make_distrib.bat %DISTRIB_DIR% || exit /b !errorlevel!

:: Go to results
cd /D ..\binary_distrib\%DISTRIB_DIR% || exit /b !errorlevel!
:: Zip results to C:\out
del /F "%BINARY_DISTRIB_ARCHIVE%" 2>nul
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
tar -czvf "%BINARY_DISTRIB_ARCHIVE%" * || exit /b !errorlevel!

GOTO :EOF


:SET_ARCH_CONFIG
if /I "%TARGETARCH%"=="amd64" (
    set "VCVARS_BAT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    set "NATIVE_JAVA_HOME_DIR=C:/jdk-17"
    set "TOOLS_JAVA_HOME_DIR=C:/jdk-17"
    set "DISTRIB_DIR=win64"
    exit /b 0
)

if /I "%TARGETARCH%"=="arm64" (
    set "VCVARS_BAT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsamd64_arm64.bat"
    set "NATIVE_JAVA_HOME_DIR=C:/jdk-17-arm64"
    set "TOOLS_JAVA_HOME_DIR=C:/jdk-17"
    set "DISTRIB_DIR=win64"
    exit /b 0
)

echo ERROR: Unsupported TARGETARCH "%TARGETARCH%"
exit /b 1


:SET_JAVA_ENV
set "JAVA_HOME=%~1"
set "PATH=%JAVA_HOME%/bin;%PATH%"
exit /b 0



:ENSURE_CHECKOUT
if exist "%JCEF_DIR%\.git" (
    echo Updating existing JCEF checkout to %REPO% at %REF%...
    cd /D "%JCEF_DIR%" || exit /b !errorlevel!
    git remote get-url origin >nul 2>&1
    if !errorlevel! equ 0 (
        git remote set-url origin "%REPO%" || exit /b !errorlevel!
    ) else (
        git remote add origin "%REPO%" || exit /b !errorlevel!
    )
    git fetch --force --tags origin "%REF%" || exit /b !errorlevel!
    git checkout --detach FETCH_HEAD || exit /b !errorlevel!
    exit /b 0
)

for /F %%I in ('dir /B /A "%JCEF_DIR%" 2^>nul') do (
    echo ERROR: %JCEF_DIR% is not empty and is not a Git checkout.
    echo Move or remove it so the requested repository and ref can be checked out safely.
    exit /b 1
)

echo Cloning JCEF from %REPO% at %REF%...
git clone "%REPO%" "%JCEF_DIR%" || exit /b !errorlevel!
cd /D "%JCEF_DIR%" || exit /b !errorlevel!
git fetch --force --tags origin "%REF%" || exit /b !errorlevel!
git checkout --detach FETCH_HEAD || exit /b !errorlevel!
exit /b 0
