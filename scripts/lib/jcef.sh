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

    if [ -d "${checkout_dir}/.git" ]; then
        echo "Updating existing JCEF checkout to ${repo} at ${ref}..."
        if git -C "${checkout_dir}" remote get-url origin > /dev/null 2>&1; then
            git -C "${checkout_dir}" remote set-url origin "${repo}"
        else
            git -C "${checkout_dir}" remote add origin "${repo}"
        fi
        retry_command git -C "${checkout_dir}" fetch --force --tags origin "${ref}"
        git -C "${checkout_dir}" checkout --detach FETCH_HEAD
        return
    fi

    if directory_has_entries "${checkout_dir}"; then
        echo "ERROR: ${checkout_dir} is not empty and is not a Git checkout." >&2
        echo "Move or remove it so the requested repository and ref can be checked out safely." >&2
        return 1
    fi

    echo "Cloning JCEF from ${repo} at ${ref}..."
    rm -rf "${checkout_dir}"
    retry_git_clone "${repo}" "${checkout_dir}"
    retry_command git -C "${checkout_dir}" fetch --force --tags origin "${ref}"
    git -C "${checkout_dir}" checkout --detach FETCH_HEAD
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
