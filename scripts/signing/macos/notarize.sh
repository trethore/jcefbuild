#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 4 ]
  then
    echo "Usage: ./scripts/signing/macos/notarize.sh <path> <applekeyid> <applekeypath> <applekeyissuer>"
    echo ""
    echo "path: the absolute(!) target path"
    echo "applekeyid: id of your apple api key"
    echo "applekeypath: path to your apple api key"
    echo "applekeyissuer: uuid of your apple api key issuer"
    exit 1
fi

echo "##########################################################"
echo "Notarizing $1... This may take a while."

TARGET_PATH=$1
APPLE_KEY_ID=$2
APPLE_KEY_PATH=$3
APPLE_KEY_ISSUER=$4
APP_DIR="$( dirname "${TARGET_PATH}" )"
APP_NAME="$( basename "${TARGET_PATH}" )"
ZIP_PATH="${TARGET_PATH}.zip"
NOTARY_OUTPUT_PATH="${APP_DIR}/notary_output.json"
NOTARIZATION_LOG_PATH="${APP_DIR}/notarization.log"

cleanup() {
    rm -f "${ZIP_PATH}" "${NOTARY_OUTPUT_PATH}" "${NOTARIZATION_LOG_PATH}"
}

trap cleanup EXIT

cd "${APP_DIR}"
echo "Creating zip"
ditto -c -k --keepParent "${APP_NAME}" "${ZIP_PATH}"

echo "Uploading ${ZIP_PATH} for notarization and waiting for result"
xcrun notarytool submit "${ZIP_PATH}" \
    --key "${APPLE_KEY_PATH}" \
    --key-id "${APPLE_KEY_ID}" \
    --issuer "${APPLE_KEY_ISSUER}" \
    --wait \
    --output-format json > "${NOTARY_OUTPUT_PATH}"

requestUUID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "${NOTARY_OUTPUT_PATH}")
status=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "${NOTARY_OUTPUT_PATH}")
if [ "${status}" != "Accepted" ]; then
    echo "ERROR: Apple notarization returned status: ${status}" >&2
    cat "${NOTARY_OUTPUT_PATH}" >&2
    exit 1
fi

echo "Notarization log:"
xcrun notarytool log "${requestUUID}" \
    --key "${APPLE_KEY_PATH}" \
    --key-id "${APPLE_KEY_ID}" \
    --issuer "${APPLE_KEY_ISSUER}" \
    "${NOTARIZATION_LOG_PATH}"
cat "${NOTARIZATION_LOG_PATH}"
echo ""

xcrun stapler staple -v "${TARGET_PATH}"

echo "##########################################################"
