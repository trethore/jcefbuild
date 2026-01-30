#!/usr/bin/env bash
set -euo pipefail

if [ -d "jcef/.git" ]; then
  echo "jcef already exists; skipping clone."
  exit 0
fi

if [ -e "jcef" ] && [ -n "$(ls -A jcef)" ]; then
  echo "jcef exists and is not empty; aborting to avoid overwriting."
  exit 1
fi

mkdir -p jcef
git clone https://github.com/trethore/jcef jcef
