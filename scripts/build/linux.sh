#!/usr/bin/env bash

if [ $# -lt 2 ] || [ $# -eq 3 ]; then
    echo "Usage: ./scripts/build/linux.sh <architecture> <buildType> [<gitrepo> <gitref>]"
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

. "${ROOT_DIR}/scripts/lib/jcef.sh"

readonly OUT_DIR="${ROOT_DIR}/out"
readonly JCEF_DIR="${ROOT_DIR}/jcef"
readonly BINARY_DISTRIB_ARCHIVE="${OUT_DIR}/binary_distrib.tar.gz"

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

build_cache_args=()
if [ "${JCEF_BUILD_CACHE:-}" = "gha" ]; then
    cache_scope="jcef-linux-${TARGETARCH}"
    build_cache_args+=(
        --cache-from "type=gha,scope=${cache_scope}"
        --cache-to "type=gha,mode=min,scope=${cache_scope}"
    )
fi

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
    --progress=plain \
    --platform="linux/${TARGETARCH}" \
    --build-arg "TARGETARCH=${TARGETARCH}" \
    --build-arg "BUILD_TYPE=${BUILD_TYPE}" \
    --build-arg "REPO=${REPO}" \
    --build-arg "REF=${REF}" \
    --file scripts/docker/DockerfileLinux \
    --output "${OUT_DIR}" \
    "${build_cache_args[@]}" \
    .

if [ ! -f "${BINARY_DISTRIB_ARCHIVE}" ]; then
    echo "ERROR: ${BINARY_DISTRIB_ARCHIVE} not found after build." >&2
    exit 1
fi
