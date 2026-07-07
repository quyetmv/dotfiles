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

# --- source checkout (clone or refresh — `chezmoi init <repo>` silently
# reuses a stale existing clone without pulling, which repeatedly shipped
# outdated templates; manage the clone ourselves) -----------------------------
if [[ -z "$REPO_ROOT" ]]; then
    repo="${CHEZMOI_REPO:-$DEFAULT_REPO}"
    case "$repo" in
        *://*|git@*) repo_url="$repo" ;;
        *)           repo_url="https://github.com/${repo}.git" ;;
    esac
    REPO_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/chezmoi"
    if [[ -d "$REPO_ROOT/.git" ]]; then
        log "Refreshing existing clone at $REPO_ROOT..."
        git -C "$REPO_ROOT" pull --ff-only || warn "Could not fast-forward $REPO_ROOT; using current checkout."
    else
        log "Cloning $repo_url..."
        git clone "$repo_url" "$REPO_ROOT"
    fi
fi

# --- init (generate config from the fresh source, no apply yet) --------------
log "chezmoi init --source $REPO_ROOT"
chezmoi init --source "$REPO_ROOT"

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

# --- age key: try Bitwarden restore, else skip encrypted ---------------------
BW_KEY_ITEM="chezmoi-age-key"

ensure_bw() {
    command -v bw >/dev/null 2>&1 && return 0
    if [[ "$OS" == "Linux" ]] && command -v snap >/dev/null 2>&1; then
        log "Installing bitwarden-cli via snap..."
        sudo snap install bw && return 0
    fi
    if command -v brew >/dev/null 2>&1; then
        log "Installing bitwarden-cli via brew..."
        brew install bitwarden-cli && return 0
    fi
    if command -v npm >/dev/null 2>&1; then
        log "Installing bitwarden-cli via npm..."
        sudo npm install -g @bitwarden/cli && return 0
    fi
    return 1
}

restore_age_key() {
    # Interactive terminals only — CI/containers keep the skip behavior
    [[ -n "${CI:-}" ]] && return 1
    [[ -r /dev/tty && -w /dev/tty ]] || return 1

    printf "Restore age key from Bitwarden (item '%s')? [y/N] " "$BW_KEY_ITEM" > /dev/tty
    local ans; read -r ans < /dev/tty
    [[ "$ans" == "y" || "$ans" == "Y" ]] || return 1

    ensure_bw || { warn "Could not install bitwarden-cli."; return 1; }

    export BW_SESSION
    if bw login --check >/dev/null 2>&1; then
        BW_SESSION="$(bw unlock --raw < /dev/tty)" || return 1
    else
        BW_SESSION="$(bw login --raw < /dev/tty)" || return 1
    fi
    bw sync >/dev/null 2>&1 || true

    mkdir -p "$(dirname "$AGE_KEY")"
    # Item is a Login whose password field holds the AGE-SECRET-KEY line
    if bw get password "$BW_KEY_ITEM" > "$AGE_KEY" 2>/dev/null && grep -q "AGE-SECRET-KEY-1" "$AGE_KEY"; then
        chmod 600 "$AGE_KEY"
        log "Age key restored to $AGE_KEY"
        return 0
    fi
    rm -f "$AGE_KEY"
    warn "Item '$BW_KEY_ITEM' not found in vault (or password field lacks an age key)."
    return 1
}

apply_args=(apply)
if [[ ! -f "$AGE_KEY" ]]; then
    if ! restore_age_key; then
        warn "No age key at $AGE_KEY — skipping encrypted secrets (~/.secrets/.private)."
        warn "Restore the key, chmod 600 it, then run: chezmoi apply"
        apply_args+=(--exclude=encrypted)
    fi
fi

# --- apply -------------------------------------------------------------------
log "chezmoi ${apply_args[*]}"
chezmoi "${apply_args[@]}"

echo ""
log "Done."
if [[ "$OS" == "Linux" ]]; then
    echo "    Next: exec zsh -l    (set terminal font to 'MesloLGS NF')"
fi
