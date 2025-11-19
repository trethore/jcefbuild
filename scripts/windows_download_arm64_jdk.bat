@echo off

:: Create download dir
mkdir jdkdl
cd jdkdl

:: Download from Microsoft
curl -L -o jdk_arm64.zip https://aka.ms/download-jdk/microsoft-jdk-17-windows-aarch64.zip

:: Unzip using jar
jar xf jdk_arm64.zip
del jdk_arm64.zip

SET a=jdk
for /D %%x in (%a%*) do if not defined f set "f=%%x"
echo Extracted to %f%

:: Move to C:\jdk-17
rename %f% jdk-17
move jdk-17 C:\

:: Remove download dir
cd ..
rmdir jdkdl

:: Print install confirmation
echo Successfully installed arm64 JDK to C:\jdk-17
