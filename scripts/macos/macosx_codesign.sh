#!/usr/bin/env bash

set -euo pipefail

if [ $# -lt 6 ]; then
    echo "Usage: ./scripts/macos/macosx_codesign.sh <path> <certname> <teamname> <applekeyid> <applekeypath> <applekeyissuer>"
    echo ""
    echo "path: the absolute(!) target path"
    echo "certname: the apple signing certificate name. Something like \"Developer ID Application: xxx (yyy)\""
    echo "teamname: the apple team name. 10-digit id yyy from the cert name."
    echo "applekeyid: id of your apple api key"
    echo "applekeypath: path to your apple api key"
    echo "applekeyissuer: uuid of your apple api key issuer"
    exit 1
fi

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

TARGET_DIR=$1
CERT_NAME=$2
TEAM_NAME=$3
APPLE_KEY_ID=$4
APPLE_KEY_PATH=$5
APPLE_KEY_ISSUER=$6

APP_DIR="${TARGET_DIR}/bin"
APP_NAME=jcef_app.app
FRAMEWORKS_DIR=Contents/Frameworks
FRAMEWORK_NAME=Chromium\ Embedded\ Framework.framework
ENTITLEMENTS_HELPER="${ROOT_DIR}/entitlements/entitlements-helper.plist"
ENTITLEMENTS_BROWSER="${ROOT_DIR}/entitlements/entitlements-browser.plist"
APP_BUNDLE="${APP_DIR}/${APP_NAME}"

codesign_runtime() {
    local entitlements=$1
    local target=$2

    codesign \
        --force \
        --options runtime \
        --entitlements "${entitlements}" \
        --sign "${CERT_NAME}" \
        --timestamp \
        --verbose \
        "${target}"
}

notarize_target() {
    local target=$1
    local bundle_id=$2

    bash "${SCRIPT_DIR}/macosx_notarize.sh" \
        "${target}" \
        "${CERT_NAME}" \
        "${TEAM_NAME}" \
        "${bundle_id}" \
        "${APPLE_KEY_ID}" \
        "${APPLE_KEY_PATH}" \
        "${APPLE_KEY_ISSUER}"
}

sign_helper() {
    local helper_name=$1
    local bundle_id=$2
    local helper_path="${APP_BUNDLE}/${FRAMEWORKS_DIR}/${helper_name}"

    codesign_runtime "${ENTITLEMENTS_HELPER}" "${helper_path}"
    notarize_target "${helper_path}" "${bundle_id}"
}

chmod -R 777 "${APP_BUNDLE}"
chmod +x "${SCRIPT_DIR}/macosx_notarize.sh"
chmod +x "${SCRIPT_DIR}/macosx_codesign_zip.sh"

#Sign helpers
echo "Signing helpers..."
sign_helper "jcef Helper.app" "org.jcef.jcef.helper"
sign_helper "jcef Helper (GPU).app" "org.jcef.jcef.helper.gpu"
sign_helper "jcef Helper (Plugin).app" "org.jcef.jcef.helper.plugin"
sign_helper "jcef Helper (Renderer).app" "org.jcef.jcef.helper.renderer"
sign_helper "jcef Helper (Alerts).app" "org.jcef.jcef.helper.alerts"

#Sign libraries and framework
echo "Signing libraries and framework..."
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/Libraries/libEGL.dylib"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/Libraries/libGLESv2.dylib"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/Libraries/libvk_swiftshader.dylib"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/Libraries/libcef_sandbox.dylib"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}/Chromium Embedded Framework"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/${FRAMEWORKS_DIR}/${FRAMEWORK_NAME}"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/Contents/Java/libjcef.dylib"
codesign_runtime \
    "${ENTITLEMENTS_BROWSER}" \
    "${APP_BUNDLE}/Contents/MacOS/JavaAppLauncher"
codesign_runtime "${ENTITLEMENTS_BROWSER}" "${APP_BUNDLE}"
notarize_target "${APP_BUNDLE}" "org.jcef.jcef"

echo "Checking notarization validity"
spctl -vvv --assess --type exec "${APP_BUNDLE}"
retVal=$?
if [ ${retVal} -ne 0 ]; then
    echo "Binaries are not correctly signed"
    exit 1
fi

echo "Done signing binaries"
