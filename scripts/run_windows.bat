@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I not "%TARGETARCH%"=="amd64" if /I not "%TARGETARCH%"=="arm64" (
    echo "Unsupported architecture %TARGETARCH%. Only amd64 and arm64 are supported."
    exit /b 1
)
echo "Building for architecture %TARGETARCH%"

:: Update ssl certs
certutil -generateSSTFromWU roots.sst && certutil -addstore -f root roots.sst && del roots.sst

:: Check residency of workdir
cd ..
if exist "jcef\README.md" (echo "Found existing files to build" && cd jcef) ^
else (echo "Did not find files to build - cloning..." && GOTO :CLONE)

:BUILD
:: CMakeLists patching 
python C:/patch_cmake.py CMakeLists.txt C:/CMakeLists.txt.patch

:: Prepare build dir
mkdir jcef_build && cd jcef_build

:: Locate Visual Studio Build Tools and load the right vcvars script.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" set "VSWHERE=C:\ProgramData\chocolatey\lib\vswhere\tools\vswhere.exe"
for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_INSTALL=%%I"
if not defined VS_INSTALL set "VS_INSTALL=C:\BuildTools"
set "VS_VCVARS=%VS_INSTALL%\VC\Auxiliary\Build"
set "VS_DEV_CMD=%VS_INSTALL%\Common7\Tools\VsDevCmd.bat"
if "%TARGETARCH%"=="amd64" (
    call "%VS_VCVARS%\vcvars64.bat"
) else (
    set "VCVARS_ARM64=%VS_VCVARS%\vcvarsamd64_arm64.bat"
    if exist "%VCVARS_ARM64%" (
        call "%VCVARS_ARM64%"
    ) else if exist "%VS_DEV_CMD%" (
        rem Fall back to VsDevCmd when the cross vcvars script is missing (happens on some BuildTools layouts)
        call "%VS_DEV_CMD%" -host_arch=amd64 -arch=arm64
    ) else (
        echo "Neither vcvarsamd64_arm64.bat nor VsDevCmd.bat were found under %VS_INSTALL%."
        dir "%VS_VCVARS%"
        exit /b 1
    )
)

:: Force desktop Windows API partition to avoid missing FILE_INFO_BY_HANDLE_CLASS in server-core images.
:: Passing these defines via CMake ensures they appear in every Ninja compile command (CL env alone is not enough).
set "WINAPI_DEFINES=/DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP /D_CRT_USE_WINAPI_FAMILY_DESKTOP_APP"
if defined CL (set "CL=%CL% %WINAPI_DEFINES%") else (set "CL=%WINAPI_DEFINES%")

if "%TARGETARCH%"=="arm64" (set "PATH=C:/jdk-11;%PATH%")

:: Perform build
if "%TARGETARCH%"=="amd64" (cmake -G "Ninja" -DJAVA_HOME="C:/Program Files/Java/jdk1.8.0_211" -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCMAKE_C_FLAGS="%WINAPI_DEFINES%" -DCMAKE_CXX_FLAGS="%WINAPI_DEFINES%" ..) || exit /b !ERRORLEVEL!
if "%TARGETARCH%"=="arm64" (cmake -G "Ninja" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=aarch64 -DJAVA_HOME="C:/jdk-11" -DCMAKE_BUILD_TYPE=%BUILD_TYPE% -DCMAKE_C_FLAGS="%WINAPI_DEFINES%" -DCMAKE_CXX_FLAGS="%WINAPI_DEFINES%" ..) || exit /b !ERRORLEVEL!
ninja -j4 || exit /b !ERRORLEVEL!

:: Compile java classes
cd ../tools
call compile.bat win64 || exit /b !ERRORLEVEL!

:: Create distribution
call make_distrib.bat win64 || exit /b !ERRORLEVEL!

:: Locate distribution directory (win64 by default, fallback to winarm64 for future-proofing)
set "DIST_PATH=..\binary_distrib\win64"
if not exist "%DIST_PATH%\" (
    set "DIST_PATH=..\binary_distrib\winarm64"
)
if not exist "%DIST_PATH%\" (
    echo "Distribution directory not found under ..\binary_distrib"
    dir ..\binary_distrib
    exit /b 1
)
pushd "%DIST_PATH%" || exit /b !ERRORLEVEL!
:: Remove wrong jogamp/gluegen natives from archive
if "%TARGETARCH%"=="arm64" (del /F bin\gluegen-rt-natives-windows-amd64.jar && del /F bin\jogl-all-natives-windows-amd64.jar)
:: Zip results to C:\out
if not exist "C:\out" mkdir "C:\out"
del /F C:\out\binary_distrib.tar.gz 2>nul
tar -czvf C:\out\binary_distrib.tar.gz * || (popd & exit /b !ERRORLEVEL!)
popd

GOTO :EOF



:CLONE
if exist jcef rmdir /S /Q jcef
git clone %REPO% jcef
cd jcef
git checkout %REF%
GOTO :BUILD
