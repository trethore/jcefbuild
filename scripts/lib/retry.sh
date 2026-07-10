#!/usr/bin/env bash

retry_command() {
    local max_attempts="${RETRY_ATTEMPTS:-5}"
    local delay_seconds="${RETRY_DELAY_SECONDS:-5}"
    local attempt=1
    local exit_code=0

    while true; do
        if "$@"; then
            return 0
        fi

        exit_code=$?
        if [ "${attempt}" -ge "${max_attempts}" ]; then
            echo "Command failed after ${attempt} attempts: $*" >&2
            return "${exit_code}"
        fi

        echo "Command failed (attempt ${attempt}/${max_attempts}, exit ${exit_code}). Retrying in ${delay_seconds}s: $*" >&2
        sleep "${delay_seconds}"
        attempt=$((attempt + 1))
    done
}

retry_git_clone() {
    if [ $# -ne 2 ]; then
        echo "Usage: retry_git_clone <repo> <destination>" >&2
        return 1
    fi

    retry_command git clone "$1" "$2"
}
