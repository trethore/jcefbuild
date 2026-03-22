#!/bin/bash

set -euo pipefail

. /builder/retry.sh

# Determine architecture
echo "Building for architecture $TARGETARCH"

if [ "${TARGETARCH}" != 'amd64' ] && [ "${TARGETARCH}" != 'arm64' ]; then
    echo "ERROR: Unsupported TARGETARCH '${TARGETARCH}'"
    exit 1
fi

if [ -z "${JAVA_HOME:-}" ]; then
    JAVA_BIN=$(readlink -f "$(command -v javac)")
    export JAVA_HOME=$(dirname "$(dirname "${JAVA_BIN}")")
fi
export PATH="${JAVA_HOME}/bin:${PATH}"

# Print some debug info
echo "-------------------------------------"
echo "JAVA_HOME: $JAVA_HOME"
echo "PATH: $PATH"
java -version
echo "-------------------------------------"

# Fetch sources
if [ ! -f "/jcef/README.md" ]; then
    echo "Did not find existing files to build - cloning..."
    rm -rf /jcef
    retry_git_clone "${REPO}" /jcef
    cd /jcef
    git checkout ${REF}
else
    echo "Found existing files to build"
    cd /jcef
fi  

#CMakeLists patching
python3 /builder/patch_cmake.py CMakeLists.txt /builder/CMakeLists.txt.patch

# Create and enter the `jcef_build` directory.
# The `jcef_build` directory name is required by other JCEF tooling
# and should not be changed.
if [ ! -d "jcef_build" ]; then
    mkdir jcef_build
fi
cd jcef_build

# Check if the download was already performed. If so, we wont send it outside of the container at the end
export already_downloaded=0
for f in ../third_party/cef/cef_binary_*; do
    test -d "$f" || continue
    #We found a matching dir
    export already_downloaded=1
    break
done

# Linux: Generate 32/64-bit Unix Makefiles.
cmake -G "Ninja" -DPROJECT_ARCH=${TARGETARCH} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ..
# Build native part using ninja.
ninja -j4

#Compile JCEF java classes
cd ../tools
chmod +x compile.sh
./compile.sh linux64

#Entering distribution phase - disable error handling (javadoc building fails here nontheless)
set -e

#Generate distribution
python3 /builder/patch_jcef_tools.py "$(pwd)"
chmod +x make_distrib.sh
./make_distrib.sh linux64

#Pack binary_distrib
cd ../binary_distrib/linux64
if [ ${BUILD_TYPE} == 'Release' ]; then (echo "Stripping binary..." && strip bin/lib/linux64/libcef.so) fi

#Export binaries
tar -czvf ../../binary_distrib.tar.gz *
mkdir ../../target
mv * ../../target

#Do not export third_party if already exported (it is quite large)
if [ "$already_downloaded" -eq "1" ]; then
    rm -rf ../../third_party/*
fi

#Export clang
mv ../../tools/buildtools/linux64 ../../buildtools
