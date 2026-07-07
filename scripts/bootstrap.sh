#!/usr/bin/env bash
# One-command dotfiles bootstrap (macOS + Linux).
#
#   Fresh machine:  curl -fsLS https://raw.githubusercontent.com/quyetmv/dotfiles/main/scripts/bootstrap.sh | bash
#   Local checkout: ./scripts/bootstrap.sh   (or: make install)
#
# Env overrides:
#   CHEZMOI_REPO   git repo to init from (default: quyetmv/dotfiles when no local checkout)
#   CI=1           skip all interactive prompts in .chezmoi.toml.tmpl

set -euo pipefail

DEFAULT_REPO="quyetmv/dotfiles"
CHEZMOI_BIN_DIR="$HOME/.local/bin"
AGE_KEY="$HOME/.config/chezmoi/chezmoi_private_key"

log()  { echo "==> $*"; }
warn() { echo "⚠️  $*" >&2; }

OS="$(uname -s)"

# Detect local checkout: $0 resolvable and repo markers present.
# When piped (curl | bash), $0 is "bash" and there is no checkout.
REPO_ROOT=""
if [[ -f "${BASH_SOURCE[0]:-}" ]]; then
    _candidate="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    [[ -f "$_candidate/.chezmoi.toml.tmpl" ]] && REPO_ROOT="$_candidate"
fi

# --- OS prerequisites -------------------------------------------------------
if [[ "$OS" == "Darwin" ]]; then
    if ! xcode-select -p &>/dev/null; then
        xcode-select --install
        echo "Re-run after Xcode CLI tools finish installing."
        exit 0
    fi
elif [[ "$OS" == "Linux" ]]; then
    if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
        log "Installing curl + git via apt..."
        sudo apt-get update -qq && sudo apt-get install -y curl git
    fi
fi

# --- chezmoi binary (idempotent, always ends up on PATH) --------------------
export PATH="$CHEZMOI_BIN_DIR:$PATH"
if ! command -v chezmoi >/dev/null 2>&1; then
    log "Installing chezmoi to $CHEZMOI_BIN_DIR..."
    mkdir -p "$CHEZMOI_BIN_DIR"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$CHEZMOI_BIN_DIR"
fi
log "chezmoi: $(command -v chezmoi)"

# --- init (clone source + generate config, no apply yet) --------------------
if [[ -n "$REPO_ROOT" ]]; then
    init_args=(init --source "$REPO_ROOT")
else
    init_args=(init "${CHEZMOI_REPO:-$DEFAULT_REPO}")
fi
log "chezmoi ${init_args[*]}"
chezmoi "${init_args[@]}"

SOURCE_DIR="$(chezmoi source-path)"

# --- Linux: system packages BEFORE apply ------------------------------------
# after_* scripts (chsh, fonts) are run_onchange: if apply runs while zsh is
# missing they skip once and never re-trigger. Install apt packages first.
if [[ "$OS" == "Linux" && -x "$SOURCE_DIR/scripts/setup-linux.sh" ]]; then
    log "Installing system packages (setup-linux.sh packages)..."
    if ! bash "$SOURCE_DIR/scripts/setup-linux.sh" packages; then
        warn "setup-linux.sh failed — continuing. Re-run later: bash $SOURCE_DIR/scripts/setup-linux.sh packages"
    fi
fi

# --- age key guard -----------------------------------------------------------
apply_args=(apply)
if [[ ! -f "$AGE_KEY" ]]; then
    warn "No age key at $AGE_KEY — skipping encrypted secrets (~/.secrets/.private)."
    warn "Restore the key (Bitwarden / another machine), chmod 600 it, then run: chezmoi apply"
    apply_args+=(--exclude=encrypted)
fi

# --- apply -------------------------------------------------------------------
log "chezmoi ${apply_args[*]}"
chezmoi "${apply_args[@]}"

echo ""
log "Done."
if [[ "$OS" == "Linux" ]]; then
    echo "    Next: exec zsh -l    (set terminal font to 'MesloLGS NF')"
fi
