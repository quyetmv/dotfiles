#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# macOS: require Xcode CLI tools
if [[ "$(uname -s)" == "Darwin" ]]; then
    if ! xcode-select -p &>/dev/null; then
        xcode-select --install
        echo "Re-run after Xcode CLI tools finish installing."
        exit 0
    fi
fi

# Linux: ensure curl and git are available
if [[ "$(uname -s)" == "Linux" ]]; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y curl git
    fi
fi

if [[ -n "${CHEZMOI_REPO:-}" ]]; then
    init_args=(init --apply "${CHEZMOI_REPO}")
else
    init_args=(init --apply --source "$REPO_ROOT")
fi

if command -v chezmoi >/dev/null 2>&1; then
    chezmoi "${init_args[@]}"
else
    sh -c "$(curl -fsLS get.chezmoi.io)" -- "${init_args[@]}"
fi
