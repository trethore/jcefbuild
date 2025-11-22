#!/bin/bash

# Small helpers to retry transient network operations (downloads, clones).
# Keeps total wait bounded with incremental backoff.

retry() {
  local attempts=$1
  shift
  local delay=${RETRY_DELAY:-5}
  local n=1
  local errexit_set=0
  if [[ $- == *e* ]]; then
    errexit_set=1
  fi

  while :; do
    set +e
    "$@"
    local rc=$?
    if [ "$errexit_set" -eq 1 ]; then
      set -e
    else
      set +e
    fi

    if [ "$rc" -eq 0 ]; then
      return 0
    fi
    if [ "$n" -ge "$attempts" ]; then
      return "$rc"
    fi
    sleep $((delay * n))
    n=$((n + 1))
  done
}

fetch_with_retry() {
  local outfile=$1
  local url=$2
  shift 2
  retry 5 curl -fL --connect-timeout 20 --retry 3 --retry-delay 2 "$@" -o "$outfile" "$url"
}
