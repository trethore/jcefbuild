#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 3 ]
  then
    echo "Usage: ./scripts/macos/macosx_codesign_zip.sh <path> <zippath> <certname>"
    echo ""
    echo "path: the absolute(!) target path"
    echo "zippath: the path inside the zip"
    echo "certname: the apple signing certificate name. Something like \"Developer ID Application: xxx (yyy)\""
    exit 1
fi

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
ENTITLEMENTS_BROWSER="${ROOT_DIR}/entitlements/entitlements-browser.plist"
TARGET_ZIP=$1
ZIP_ENTRY=$2
CERT_NAME=$3
TMP_DIR="${SCRIPT_DIR}/tmp"

cleanup() {
    rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

rm -rf "${TMP_DIR}"
mkdir "${TMP_DIR}"

unzip "${TARGET_ZIP}" "${ZIP_ENTRY}" -d "${TMP_DIR}"
codesign \
    --force \
    --options runtime \
    --entitlements "${ENTITLEMENTS_BROWSER}" \
    --sign "${CERT_NAME}" \
    --timestamp \
    --verbose \
    "${TMP_DIR}/${ZIP_ENTRY}"

cd "${TMP_DIR}"
zip --update "${TARGET_ZIP}" "${ZIP_ENTRY}"
