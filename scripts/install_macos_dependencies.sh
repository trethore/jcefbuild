#!/bin/bash
set -euo pipefail

PYTHON=python3

# Prefer existing Homebrew ninja to avoid noisy reinstall message on GitHub runners.
if ! brew list --versions ninja >/dev/null 2>&1; then
  brew install ninja
else
  echo "ninja already installed: $(brew list --versions ninja)"
fi

pip3 install --break-system-packages --user six

"$PYTHON" -m pip list
echo "from six.moves import configparser" | "$PYTHON" && echo "Success importing stuff from six moves python module"
