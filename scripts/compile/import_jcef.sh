#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
ROOT_DIR=$(cd "${SCRIPT_DIR}/../.." && pwd)

. "${ROOT_DIR}/scripts/common/retry.sh"
. "${ROOT_DIR}/scripts/common/jcef.sh"

readonly JCEF_DIR="${ROOT_DIR}/jcef"

cd "${ROOT_DIR}"

if [ -d "${JCEF_DIR}/.git" ]; then
  echo "jcef already exists; skipping clone."
  exit 0
fi

if directory_has_entries "${JCEF_DIR}"; then
  echo "jcef exists and is not empty; aborting to avoid overwriting."
  exit 1
fi

ensure_directory "${JCEF_DIR}"
retry_git_clone "${DEFAULT_JCEF_REPO}" "${JCEF_DIR}"
