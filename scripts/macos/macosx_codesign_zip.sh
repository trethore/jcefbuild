#!/bin/bash

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

rm -rf "${SCRIPT_DIR}/tmp"
mkdir "${SCRIPT_DIR}/tmp"
unzip "$1" "$2" -d "${SCRIPT_DIR}/tmp"
codesign --force --options runtime --entitlements "$ENTITLEMENTS_BROWSER" --sign "$3" --timestamp --verbose "${SCRIPT_DIR}/tmp/$2"
cd "${SCRIPT_DIR}/tmp"
zip --update "$1" "$2"
cd "${SCRIPT_DIR}"
rm -rf "${SCRIPT_DIR}/tmp"
