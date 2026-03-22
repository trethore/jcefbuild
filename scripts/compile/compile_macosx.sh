#!/usr/bin/env bash

if [ $# -ne 2 ] && [ $# -ne 4 ] && [ $# -ne 9 ]; then
    echo "Usage: ./scripts/compile/compile_macosx.sh <architecture> <buildType> [<gitrepo> <gitref>] [<certname> <teamname> <applekeyid> <applekeypath> <applekeyissuer>]"
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

set -euo pipefail

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
WORK_DIR="${ROOT_DIR}"

. "${ROOT_DIR}/scripts/common/retry.sh"
. "${ROOT_DIR}/scripts/common/jcef.sh"

readonly JCEF_DIR="${ROOT_DIR}/jcef"
readonly JCEF_BUILD_DIR="${JCEF_DIR}/jcef_build"
readonly TOOLS_DIR="${JCEF_DIR}/tools"
readonly OUT_DIR="${WORK_DIR}/out"
readonly DISTRIB_DIR="macosx64"
readonly JAVADOC_EXPORTS='javadoc --add-exports=java.desktop/java.awt.peer=ALL-UNNAMED --add-exports=java.desktop/sun.awt=ALL-UNNAMED --add-exports=java.desktop/sun.lwawt=ALL-UNNAMED --add-exports=java.desktop/sun.lwawt.macosx=ALL-UNNAMED '

create_tarball_from_dir() {
    local archive_path=$1
    local source_dir=$2

    tar -czvf "${archive_path}" -C "${source_dir}" .
}

cd "${ROOT_DIR}"

TARGETARCH=$1
BUILD_TYPE=$2
if [ $# -lt 4 ]; then
    REPO=${DEFAULT_JCEF_REPO}
    REF=${DEFAULT_JCEF_REF}
else
    REPO=$3
    REF=$4
fi

# Determine architecture
echo "Building for architecture ${TARGETARCH}"

require_supported_arch "${TARGETARCH}"

ensure_checkout "${JCEF_DIR}" "${REPO}" "${REF}"
cd "${JCEF_DIR}"

# Create and enter the `jcef_build` directory.
# The `jcef_build` directory name is required by other JCEF tooling
# and should not be changed.
ensure_directory "${JCEF_BUILD_DIR}"
cd "${JCEF_BUILD_DIR}"

# MacOS: Generate amd64/arm64 Makefiles.
if [ "${TARGETARCH}" = 'amd64' ]; then
    PROJECT_ARCH=x86_64
else
    PROJECT_ARCH=arm64
fi

cmake \
    -G "Ninja" \
    -DPROJECT_ARCH="${PROJECT_ARCH}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    ..
# Build native part using ninja.
ninja -j4

#Generate distribution
cd "${TOOLS_DIR}"
python3 "${WORK_DIR}/scripts/patch/patch_jcef_tools.py" "$(pwd)"
if [ -f make_docs.sh ]; then
    sed -i "" 's/--ignore-source-errors//g' make_docs.sh
    if ! grep -q -- '--add-exports=java.desktop/sun.lwawt=ALL-UNNAMED' make_docs.sh; then
        sed -i "" \
            "s|javadoc |${JAVADOC_EXPORTS}|" \
            make_docs.sh
    fi
    if ! ./make_docs.sh; then
        if [ ! -d ../out/docs ]; then
            echo "ERROR: Javadoc generation failed and no docs were produced." >&2
            exit 1
        fi
    fi
fi
chmod +x make_distrib.sh
./make_distrib.sh "${DISTRIB_DIR}"
cd ..

#Perform code signing
cd "binary_distrib/${DISTRIB_DIR}"
if [ $# -gt 4 ]; then
    chmod +x "${WORK_DIR}/scripts/macos/macosx_codesign.sh"
    bash "${WORK_DIR}/scripts/macos/macosx_codesign.sh" \
        "$(pwd)" \
        "$5" \
        "$6" \
        "$7" \
        "$8" \
        "$9"
    retVal=$?
    if [ ${retVal} -ne 0 ]; then
        echo "Binaries are not correctly signed"
        exit 1
    fi
fi

#Pack binary_distrib
rm -rf "${OUT_DIR}"
mkdir "${OUT_DIR}"
tar -czvf "${OUT_DIR}/binary_distrib.tar.gz" *

#Pack javadoc
if [ -d docs ]; then
    create_tarball_from_dir "${OUT_DIR}/javadoc.tar.gz" docs
elif [ -d ../../out/docs ]; then
    create_tarball_from_dir "${OUT_DIR}/javadoc.tar.gz" ../../out/docs
else
    echo "ERROR: javadoc docs directory not found (expected binary_distrib/macosx64/docs or out/docs)." >&2
    exit 1
fi
