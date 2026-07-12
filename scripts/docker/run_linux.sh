#!/usr/bin/env bash

set -euo pipefail

. /builder/retry.sh
. /builder/jcef.sh

readonly BUILDER_DIR="/builder"
readonly JCEF_DIR="/jcef"
readonly JCEF_BUILD_DIR="${JCEF_DIR}/jcef_build"
readonly TOOLS_DIR="${JCEF_DIR}/tools"
readonly DISTRIB_DIR="linux64"

configure_java_home() {
    if [ -z "${JAVA_HOME:-}" ]; then
        local java_bin

        java_bin=$(readlink -f "$(command -v javac)")
        export JAVA_HOME=$(dirname "$(dirname "${java_bin}")")
    fi

    export PATH="${JAVA_HOME}/bin:${PATH}"
}

# Determine architecture
echo "Building for architecture ${TARGETARCH}"

require_supported_arch "${TARGETARCH}"

configure_java_home

# Print some debug info
echo "-------------------------------------"
echo "JAVA_HOME: ${JAVA_HOME}"
echo "PATH: ${PATH}"
java -version
echo "-------------------------------------"

# Fetch sources
ensure_checkout "${JCEF_DIR}" "${REPO}" "${REF}"
cd "${JCEF_DIR}"

#CMakeLists patching
python3 "${BUILDER_DIR}/patch_cmake.py" CMakeLists.txt "${BUILDER_DIR}/CMakeLists.txt.patch"

# Create and enter the `jcef_build` directory.
# The `jcef_build` directory name is required by other JCEF tooling
# and should not be changed.
ensure_directory "${JCEF_BUILD_DIR}"
cd "${JCEF_BUILD_DIR}"

# Check if the download was already performed. If so, we wont send it outside of the container at the end
already_downloaded=0
if pattern_has_match "../third_party/cef/cef_binary_*"; then
    already_downloaded=1
fi

# Linux: Generate 32/64-bit Unix Makefiles.
cmake \
    -G "Ninja" \
    -DPROJECT_ARCH="${TARGETARCH}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    ..
# Build native part using all CPUs available to the container.
ninja -j"$(nproc)"

#Compile JCEF java classes
cd "${TOOLS_DIR}"
chmod +x compile.sh
./compile.sh "${DISTRIB_DIR}"

#Generate distribution
python3 "${BUILDER_DIR}/patch_jcef_tools.py" "$(pwd)"
chmod +x make_distrib.sh
./make_distrib.sh "${DISTRIB_DIR}"

#Pack binary_distrib
cd "../binary_distrib/${DISTRIB_DIR}"
if [ "${BUILD_TYPE}" = 'Release' ]; then
    echo "Stripping binary..."
    strip "bin/lib/${DISTRIB_DIR}/libcef.so"
fi

#Export binaries
tar -czvf ../../binary_distrib.tar.gz *
mkdir ../../target
mv * ../../target

#Do not export third_party if already exported (it is quite large)
if [ "$already_downloaded" -eq "1" ]; then
    rm -rf ../../third_party/*
fi

#Export clang
mv "../../tools/buildtools/${DISTRIB_DIR}" ../../buildtools
