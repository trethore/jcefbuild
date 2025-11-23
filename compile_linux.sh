#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ] || [ $# -eq 3 ]
  then
    echo "Usage: ./compile_linux.sh <architecture> <buildType> [<gitrepo> <gitref>]"
    echo ""
    echo "architecture: the target architecture to build for. Architectures are either arm64 or amd64."
    echo "buildType: either Release or Debug"
    echo "gitrepo: git repository url to clone"
    echo "gitref: the git commit id to pull"
    exit 1
fi

cd "$( dirname "$0" )"

#Remove old build output
rm -rf out
mkdir out

#Remove binary distribution if there was one built before (saves transfer of it to docker context)
rm -rf jcef/binary_distrib

#Execute buildx with linux dockerfile and output to current directory
ARCH="$1"
case "$ARCH" in
  amd64|arm64) ;;
  *)
    echo "Unsupported architecture $ARCH. Only amd64 and arm64 are supported."
    exit 1
    ;;
esac
PLATFORM="linux/$ARCH"
BUILD_TYPE="$2"
DEFAULT_REPO="https://github.com/trethore/java-cef.git"
DEFAULT_REF="master"

if [ $# -eq 2 ]; then
  REPO="$DEFAULT_REPO"
  REF="$DEFAULT_REF"
else
  REPO="$3"
  REF="$4"
fi

CACHE_ROOT="${BUILDX_CACHE_ROOT:-}"
SAFE_ARCH="${ARCH//\//_}"
PRIMARY_CACHE_FROM=()
PRIMARY_CACHE_TO=()
PRIMARY_CACHE_DIR=""
PRIMARY_CACHE_TEMP=""
if [ -n "$CACHE_ROOT" ]; then
  mkdir -p "$CACHE_ROOT"
  PRIMARY_CACHE_DIR="$CACHE_ROOT/linux-${SAFE_ARCH}"
  mkdir -p "$PRIMARY_CACHE_DIR"
  PRIMARY_CACHE_TEMP="${PRIMARY_CACHE_DIR}-tmp"
  rm -rf "$PRIMARY_CACHE_TEMP"
  if [ -f "$PRIMARY_CACHE_DIR/index.json" ]; then
    PRIMARY_CACHE_FROM=(--cache-from "type=local,src=$PRIMARY_CACHE_DIR")
  fi
  PRIMARY_CACHE_TO=(--cache-to "type=local,dest=$PRIMARY_CACHE_TEMP,mode=max")
fi

docker buildx build --no-cache --progress=plain --platform="$PLATFORM" \
  --build-arg TARGETARCH="$ARCH" \
  --build-arg BUILD_TYPE="$BUILD_TYPE" \
  --build-arg REPO="$REPO" \
  --build-arg REF="$REF" \
  --file docker/DockerfileLinux \
  "${PRIMARY_CACHE_FROM[@]}" \
  "${PRIMARY_CACHE_TO[@]}" \
  --output out .
if [ -n "$PRIMARY_CACHE_TEMP" ] && [ -d "$PRIMARY_CACHE_TEMP" ]; then
  rm -rf "$PRIMARY_CACHE_DIR"
  mv "$PRIMARY_CACHE_TEMP" "$PRIMARY_CACHE_DIR"
fi
if [ -z "$CACHE_ROOT" ]; then
  docker builder prune -f --filter "label=jcefbuild=true" || true
fi
rm -f out/third_party/cef/*.bz2 out/third_party/cef/*.sha1

# Check if the cef download was performed. If so, move third_party dir to jcef dir
export downloaded=0
for f in out/third_party/cef/cef_binary_*; do
    test -d "$f" || continue
    #We found a matching dir
    export downloaded=1
    break
done
if [ "$downloaded" -eq "1" ]; then
    rm -rf jcef/third_party
    mv out/third_party jcef
else
    rm -rf out/third_party
fi

# Check if the clang download was performed. If so, move it to jcef dir
if [ -f "out/buildtools/clang-format" ]; then
    rm -rf jcef/tools/buildtools/linux64
    mv out/buildtools jcef/tools/buildtools/linux64
fi

#Move jcef_build
if [ -f "out/jcef_build" ]; then
    rm -rf jcef/jcef_build
    mv out/jcef_build jcef/jcef_build
fi

#Move target to binary_distrib
if [ -f "out/target" ]; then
    rm -rf jcef/binary_distrib
    mv out/target jcef/binary_distrib
fi
