#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 5 ]; then
    echo "Usage: ./scripts/signing/macos/codesign.sh <path> <certname> <applekeyid> <applekeypath> <applekeyissuer>"
    echo ""
    echo "path: the absolute(!) target path"
    echo "certname: the apple signing certificate name. Something like \"Developer ID Application: xxx (yyy)\""
    echo "applekeyid: id of your apple api key"
    echo "applekeypath: path to your apple api key"
    echo "applekeyissuer: uuid of your apple api key issuer"
    exit 1
fi

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

TARGET_DIR=$1
CERT_NAME=$2
APPLE_KEY_ID=$3
APPLE_KEY_PATH=$4
APPLE_KEY_ISSUER=$5

APP_DIR="${TARGET_DIR}/bin"
APP_NAME=jcef_app.app
FRAMEWORKS_DIR=Contents/Frameworks
FRAMEWORK_NAME=Chromium\ Embedded\ Framework.framework
ENTITLEMENTS_HELPER="${SCRIPT_DIR}/entitlements-helper.plist"
ENTITLEMENTS_BROWSER="${SCRIPT_DIR}/entitlements-browser.plist"
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

    bash "${SCRIPT_DIR}/notarize.sh" \
        "${target}" \
        "${APPLE_KEY_ID}" \
        "${APPLE_KEY_PATH}" \
        "${APPLE_KEY_ISSUER}"
}

sign_helper() {
    local helper_name=$1
    local helper_path="${APP_BUNDLE}/${FRAMEWORKS_DIR}/${helper_name}"

    codesign_runtime "${ENTITLEMENTS_HELPER}" "${helper_path}"
}

chmod -R u+rwX "${APP_BUNDLE}"
chmod +x "${SCRIPT_DIR}/notarize.sh"

#Sign helpers
echo "Signing helpers..."
sign_helper "jcef Helper.app"
sign_helper "jcef Helper (GPU).app"
sign_helper "jcef Helper (Plugin).app"
sign_helper "jcef Helper (Renderer).app"
sign_helper "jcef Helper (Alerts).app"

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

echo "Verifying code signatures..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

notarize_target "${APP_BUNDLE}"

echo "Checking notarization validity"
spctl -vvv --assess --type exec "${APP_BUNDLE}"

echo "Done signing binaries"
