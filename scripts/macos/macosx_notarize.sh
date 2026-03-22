#!/usr/bin/env bash

set -euo pipefail

#Contents partly stolen from https://scriptingosx.com/2019/09/notarize-a-command-line-tool/
#Will need updating for XCode 13+

if [ $# -lt 7 ]
  then
    echo "Usage: ./scripts/macos/macosx_notarize.sh <path> <certname> <teamname> <bundleid> <applekeyid> <applekeypath> <applekeyissuer>"
    echo ""
    echo "path: the absolute(!) target path"
    echo "certname: the apple signing certificate name. Something like \"Developer ID Application: xxx (yyy)\""
    echo "teamname: the apple team name. 10-digit id yyy from the cert name."
    echo "bundleid: the bundle id of the artifact"
    echo "applekeyid: id of your apple api key"
    echo "applekeypath: path to your apple api key"
    echo "applekeyissuer: uuid of your apple api key issuer"
    exit 1
fi

echo "##########################################################"
echo "Notarizing $1... This may take a while."

TARGET_PATH=$1
CERT_NAME=$2
TEAM_NAME=$3
BUNDLE_ID=$4
APPLE_KEY_ID=$5
APPLE_KEY_PATH=$6
APPLE_KEY_ISSUER=$7
APP_DIR="$( dirname "${TARGET_PATH}" )"
APP_NAME="$( basename "${TARGET_PATH}" )"
ZIP_PATH="${TARGET_PATH}.zip"
NOTARY_OUTPUT_PATH="${APP_DIR}/notary_output.txt"
NOTARIZATION_LOG_PATH="${APP_DIR}/notarization.log"

cd "${APP_DIR}"
echo "Creating zip"
zip -r "${APP_NAME}.zip" "${APP_NAME}"

echo "Uploading ${ZIP_PATH} for notarization and waiting for result"
xcrun notarytool submit "${ZIP_PATH}" \
    --key "${APPLE_KEY_PATH}" \
    --key-id "${APPLE_KEY_ID}" \
    --issuer "${APPLE_KEY_ISSUER}" \
    --wait 2>&1 | tee "${NOTARY_OUTPUT_PATH}"

rm "${APP_NAME}.zip"
requestUUID=$(awk '/id:/ { print $NF; exit; }' "${NOTARY_OUTPUT_PATH}")
rm "${NOTARY_OUTPUT_PATH}"

echo "Notarization log:"
xcrun notarytool log "${requestUUID}" \
    --key "${APPLE_KEY_PATH}" \
    --key-id "${APPLE_KEY_ID}" \
    --issuer "${APPLE_KEY_ISSUER}" \
    "${NOTARIZATION_LOG_PATH}"
cat "${NOTARIZATION_LOG_PATH}"
rm -f "${NOTARIZATION_LOG_PATH}"
echo ""

# staple
xcrun stapler staple -v "${TARGET_PATH}"

echo "##########################################################"
