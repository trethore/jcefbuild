#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)
PYTHON_BIN=python3

. "${ROOT_DIR}/scripts/common/retry.sh"

retry_command brew install ninja
retry_command pip3 install \
    --break-system-packages \
    --user \
    six

"${PYTHON_BIN}" -m pip list
echo "from six.moves import configparser" | "${PYTHON_BIN}" \
    && echo "Success importing stuff from six moves python module"
