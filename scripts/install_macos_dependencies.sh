#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/net_retry.sh"

PYTHON=python3

# Prefer existing Homebrew ninja to avoid noisy reinstall message on GitHub runners.
if ! brew list --versions ninja >/dev/null 2>&1; then
  retry 3 brew install ninja
else
  echo "ninja already installed: $(brew list --versions ninja)"
fi

retry 3 pip3 install --break-system-packages --user six

"$PYTHON" -m pip list
echo "from six.moves import configparser" | "$PYTHON" && echo "Success importing stuff from six moves python module"
