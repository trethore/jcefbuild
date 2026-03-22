#!/usr/bin/env bash

if [ $# -lt 2 ] || [ $# -eq 3 ]; then
    echo "Usage: ./scripts/compile/compile_linux.sh <architecture> <buildType> [<gitrepo> <gitref>]"
    echo ""
    echo "architecture: the target architecture to build for. Architectures are either arm64 or amd64."
    echo "buildType: either Release or Debug"
    echo "gitrepo: git repository url to clone"
    echo "gitref: the git commit id to pull"
    exit 1
fi

set -euo pipefail

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

. "${ROOT_DIR}/scripts/common/jcef.sh"

readonly OUT_DIR="${ROOT_DIR}/out"
readonly JCEF_DIR="${ROOT_DIR}/jcef"
readonly BINARY_DISTRIB_ARCHIVE="${OUT_DIR}/binary_distrib.tar.gz"

move_output_if_present() {
    local source_path=$1
    local destination_path=$2

    if [ -e "${source_path}" ]; then
        rm -rf "${destination_path}"
        mv "${source_path}" "${destination_path}"
    fi
}

TARGETARCH=$1
BUILD_TYPE=$2
if [ $# -eq 2 ]; then
    REPO=${DEFAULT_JCEF_REPO}
    REF=${DEFAULT_JCEF_REF}
else
    REPO=$3
    REF=$4
fi

require_supported_arch "${TARGETARCH}"

cd "${ROOT_DIR}"

#Remove old build output
rm -rf "${OUT_DIR}"
mkdir "${OUT_DIR}"

#Remove binary distribution if there was one built before (saves transfer of it to docker context)
rm -rf "${JCEF_DIR}/binary_distrib"
#Ensure build context always has a jcef dir
mkdir -p "${JCEF_DIR}"

#Execute buildx with linux dockerfile and output to current directory
docker buildx build \
    --no-cache \
    --progress=plain \
    --platform="linux/${TARGETARCH}" \
    --build-arg "TARGETARCH=${TARGETARCH}" \
    --build-arg "BUILD_TYPE=${BUILD_TYPE}" \
    --build-arg "REPO=${REPO}" \
    --build-arg "REF=${REF}" \
    --file scripts/docker/DockerfileLinux \
    --output "${OUT_DIR}" \
    .
docker builder prune -f --filter "label=jcefbuild=true"

if [ ! -f "${BINARY_DISTRIB_ARCHIVE}" ]; then
    echo "ERROR: ${BINARY_DISTRIB_ARCHIVE} not found after build." >&2
    exit 1
fi

#Cleanup output dir
rm -f "${OUT_DIR}"/third_party/cef/*.bz2 "${OUT_DIR}"/third_party/cef/*.sha1

# Check if the cef download was performed. If so, move third_party dir to jcef dir
if pattern_has_match "${OUT_DIR}/third_party/cef/cef_binary_*"; then
    rm -rf "${JCEF_DIR}/third_party"
    mv "${OUT_DIR}/third_party" "${JCEF_DIR}"
else
    rm -rf "${OUT_DIR}/third_party"
fi

# Check if the clang download was performed. If so, move it to jcef dir
if [ -f "${OUT_DIR}/buildtools/clang-format" ]; then
    move_output_if_present \
        "${OUT_DIR}/buildtools" \
        "${JCEF_DIR}/tools/buildtools/linux64"
fi

#Move jcef_build
if [ -e "${OUT_DIR}/jcef_build" ]; then
    move_output_if_present \
        "${OUT_DIR}/jcef_build" \
        "${JCEF_DIR}/jcef_build"
fi

#Move target to binary_distrib
if [ -e "${OUT_DIR}/target" ]; then
    move_output_if_present \
        "${OUT_DIR}/target" \
        "${JCEF_DIR}/binary_distrib"
fi
