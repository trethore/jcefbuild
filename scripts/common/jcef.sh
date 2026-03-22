#!/usr/bin/env bash

: "${DEFAULT_JCEF_REPO:=https://github.com/trethore/jcef.git}"
: "${DEFAULT_JCEF_REF:=master}"

require_supported_arch() {
    local target_arch=${1:-}

    case "${target_arch}" in
        amd64|arm64)
            ;;
        *)
            echo "ERROR: Unsupported architecture '${target_arch}'. Supported architectures are amd64 and arm64." >&2
            return 1
            ;;
    esac
}

ensure_checkout() {
    if [ $# -ne 3 ]; then
        echo "Usage: ensure_checkout <path> <repo> <ref>" >&2
        return 1
    fi

    local checkout_dir=$1
    local repo=$2
    local ref=$3

    if [ ! -f "${checkout_dir}/README.md" ]; then
        echo "Did not find existing files to build - cloning..."
        rm -rf "${checkout_dir}"
        retry_git_clone "${repo}" "${checkout_dir}"
        git -C "${checkout_dir}" checkout "${ref}"
    else
        echo "Found existing files to build"
    fi
}

ensure_directory() {
    if [ $# -ne 1 ]; then
        echo "Usage: ensure_directory <path>" >&2
        return 1
    fi

    mkdir -p "$1"
}

directory_has_entries() {
    if [ $# -ne 1 ]; then
        echo "Usage: directory_has_entries <path>" >&2
        return 1
    fi

    local directory=$1
    local entries=()

    if [ ! -d "${directory}" ]; then
        return 1
    fi

    shopt -s dotglob nullglob
    entries=("${directory}"/*)
    shopt -u dotglob nullglob

    [ ${#entries[@]} -gt 0 ]
}

pattern_has_match() {
    if [ $# -ne 1 ]; then
        echo "Usage: pattern_has_match <glob-pattern>" >&2
        return 1
    fi

    compgen -G "$1" > /dev/null
}
