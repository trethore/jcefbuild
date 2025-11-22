#!/bin/bash
set -euo pipefail

cd "$( dirname "$0" )"
WORK_DIR=$(pwd)

source "$WORK_DIR/scripts/net_retry.sh"

# Fail fast on invalid invocation so subsequent commands don't mask the problem.
if [ $# -lt 2 ] || [ $# -eq 3 ]
  then
    echo "Usage: ./compile_macosx.sh <architecture> <buildType> [<gitrepo> <gitref>] [<certname> <teamname> <applekeyid> <applekeypath> <applekeyissuer>]"
    echo ""
    echo "architecture: the target architecture to build for. Architectures are either amd64 or arm64."
    echo "buildType: either Release or Debug"
    echo "gitrepo: git repository url to clone"
    echo "gitref: the git commit id to pull"
    echo "certname: the apple signing certificate name. Something like \"Developer ID Application: xxx (yyy)\""
    echo "teamname: the apple team name. 10-digit id yyy from the cert name."
    echo "applekeyid: id of your apple api key"
    echo "applekeypath: path to your apple api key"
    echo "applekeyissuer: uuid of your apple api key issuer"
    exit 1
fi

TARGETARCH=$1
BUILD_TYPE=$2
if [ $# -lt 4 ]
  then
    REPO=https://github.com/trethore/java-chromium-embedded-framework.git
    REF=master
else
    REPO=$3
    REF=$4
fi

# Determine architecture
echo "Building for architecture $TARGETARCH"

if [ ! -f "jcef/README.md" ]; then
    echo "Did not find existing files to build - cloning..."
    rm -rf jcef
    retry 3 git clone "${REPO}" jcef
    cd jcef
    git checkout ${REF}
    #No CMakeLists patching required on macos, as we do not add any new platforms
else
    echo "Found existing files to build"
    cd jcef
fi

# Ensure we use an x86_64 Java when targeting amd64 to avoid linker errors
# like "found architecture 'arm64', required architecture 'x86_64'".
ensure_java_arch() {
    local expected_arch="$1"
    local java_bin="${JAVA_HOME:-}/bin/java"

    if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$java_bin" ]; then
        echo "JAVA_HOME is not set to a valid JDK (expected $expected_arch)."
        return 1
    fi

    local archs
    archs=$(lipo -archs "$java_bin" 2>/dev/null || true)
    if [ -z "$archs" ]; then
        archs=$(file -b "$java_bin" 2>/dev/null || true)
    fi

    if echo "$archs" | grep -q "$expected_arch"; then
        echo "Detected JAVA_HOME with $expected_arch support: $JAVA_HOME ($archs)"
        return 0
    fi

    return 1
}

# On Apple Silicon runners, setup-java installs an arm64 JDK by default.
# For x86_64 builds we need an x64 JDK to satisfy the linker.
if [ "${TARGETARCH}" = "amd64" ]; then
    if ! ensure_java_arch "x86_64"; then
        echo "Detected non-x86_64 JDK while building x86_64. Downloading x64 JDK 17..."
        JDK_X64_DIR="$WORK_DIR/.jdk17_x64"
        mkdir -p "$JDK_X64_DIR"
        tmp_tar=$(mktemp "$JDK_X64_DIR/jdk17_x64.XXXX.tar.gz")

        download_jdk() {
            local url="$1"
            echo "Fetching JDK from $url"
            fetch_with_retry "$tmp_tar" "$url"
        }

        # Primary (stable) URL, fallback to API endpoint if GitHub redirect changes.
        if ! download_jdk "https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_mac_hotspot.tar.gz" \
           && ! download_jdk "https://api.adoptium.net/v3/binary/latest/17/ga/mac/x64/jdk/hotspot/normal/eclipse"; then
            echo "Failed to download x64 JDK 17" >&2
            exit 1
        fi

        # Basic integrity check to avoid extracting HTML error pages.
        if ! tar -tzf "$tmp_tar" >/dev/null 2>&1; then
            echo "Downloaded JDK archive is not a valid tar.gz" >&2
            exit 1
        fi

        (
            cd "$JDK_X64_DIR"
            tar -xzf "$tmp_tar"
        )

        # Prefer macOS bundle layout .../jdk-17*.jdk/Contents/Home, but also
        # handle tarballs that unpack to jdk-17*/ without the .jdk suffix.
        JDK_ROOT=$(find "$JDK_X64_DIR" -maxdepth 2 -type d -name "jdk-17*" | head -n1)
        CANDIDATE_HOME=""
        if [ -n "$JDK_ROOT" ] && [ -d "$JDK_ROOT/Contents/Home" ]; then
            CANDIDATE_HOME="$JDK_ROOT/Contents/Home"
        elif [ -n "$JDK_ROOT" ] && [ -x "$JDK_ROOT/bin/java" ]; then
            CANDIDATE_HOME="$JDK_ROOT"
        else
            CANDIDATE_HOME=$(find "$JDK_X64_DIR" -maxdepth 4 -type d -path "*/Contents/Home" | head -n1)
        fi

        if [ -z "$CANDIDATE_HOME" ] || [ ! -x "$CANDIDATE_HOME/bin/java" ]; then
            echo "Could not locate extracted JDK 17 Home in $JDK_X64_DIR" >&2
            exit 1
        fi

        JAVA_HOME="$CANDIDATE_HOME"
        export JAVA_HOME
        export PATH="$JAVA_HOME/bin:$PATH"
        echo "Switched JAVA_HOME to $JAVA_HOME"
    fi
fi

# For arm64 builds ensure JAVA_HOME actually contains arm64 binaries; otherwise subtle
# failures show up during Ant bundling. We don't auto-download here because GH runners
# already provide arm64 JDKs, but we fail fast with a clear message.
if [ "${TARGETARCH}" = "arm64" ]; then
    if ! ensure_java_arch "arm64"; then
        echo "Detected non-arm64 JDK while building arm64. Set JAVA_HOME to an arm64 JDK." >&2
        exit 1
    fi
fi

# Create and enter the `jcef_build` directory.
# The `jcef_build` directory name is required by other JCEF tooling
# and should not be changed.
if [ ! -d "jcef_build" ]; then
    mkdir jcef_build
fi
cd jcef_build

# MacOS: Generate amd64/arm64 Makefiles.
if [ ${TARGETARCH} == 'amd64' ]; then
    cmake -G "Ninja" -DPROJECT_ARCH="x86_64" -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ..
else
    cmake -G "Ninja" -DPROJECT_ARCH="arm64" -DCMAKE_BUILD_TYPE=${BUILD_TYPE} ..
fi
# Build native part using ninja and stop immediately if it fails. Capture the
# full log so CI artifacts can surface the failing command; verbosity is
# controlled by optional env vars.
export NINJA_STATUS=${NINJA_STATUS:-""}
NINJA_FLAGS=${NINJA_FLAGS:-""}
mkdir -p "$WORK_DIR/out"
NINJA_LOG="$WORK_DIR/out/ninja_macos_${TARGETARCH}.log"

if ! ninja $NINJA_FLAGS -j4 2>&1 | tee "$NINJA_LOG"; then
    echo "Ninja build failed; aborting macOS packaging." >&2
    echo "See log: $NINJA_LOG" >&2
    exit 1
fi

#Generate distribution
cd ../tools
sed -i "" 's/--ignore-source-errors//g' make_docs.sh
chmod +x make_distrib.sh
./make_distrib.sh macosx64
cd ..

#Perform code signing
cd binary_distrib/macosx64
if [ $# -gt 4 ]
  then
    chmod +x $WORK_DIR/macosx_codesign.sh
    bash $WORK_DIR/macosx_codesign.sh $(pwd) "$5" $6 $7 $8 $9
    retVal=$?
    if [ $retVal -ne 0 ]; then
        echo "Binaries are not correctly signed"
        exit 1
    fi
fi

#Pack binary_distrib
rm -rf ../../../out
mkdir ../../../out
tar -czvf ../../../out/binary_distrib.tar.gz *

#Pack javadoc
cd docs
tar -czvf ../../../../out/javadoc.tar.gz *
