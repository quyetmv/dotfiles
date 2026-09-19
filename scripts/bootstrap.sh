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

can_decrypt_secrets() {
    [[ -s "$AGE_KEY" ]] || return 1
    local test_file=""
    [[ -n "${REPO_ROOT:-}" && -f "$REPO_ROOT/private_dot_secrets/encrypted_private_dot_private.age" ]] && test_file="$REPO_ROOT/private_dot_secrets/encrypted_private_dot_private.age"
    [[ -z "$test_file" && -n "${SOURCE_DIR:-}" && -f "$SOURCE_DIR/private_dot_secrets/encrypted_private_dot_private.age" ]] && test_file="$SOURCE_DIR/private_dot_secrets/encrypted_private_dot_private.age"

    if [[ -n "$test_file" ]]; then
        chezmoi decrypt "$test_file" >/dev/null 2>&1
    else
        grep -q "AGE-SECRET-KEY-1" "$AGE_KEY" 2>/dev/null
    fi
}

restore_age_key() {
    local _BW_PORT=8087
    local extracted_key=""

    # 1. Try local REST server first (matches 60-devops.zsh / bwu, eliminates prompts & latency)
    if curl -sf "http://localhost:${_BW_PORT}/status" 2>/dev/null | jq -e '.data.template.status == "unlocked"' >/dev/null 2>&1; then
        log "Bitwarden local REST API active and unlocked. Fetching '$BW_KEY_ITEM'..."
        local item_json
        item_json="$(curl -sf "http://localhost:${_BW_PORT}/list/object/items?search=${BW_KEY_ITEM}" 2>/dev/null \
            | jq -r --arg n "$BW_KEY_ITEM" '.data.data[] | select(.name == $n)' 2>/dev/null || true)"
        if [[ -n "$item_json" && "$item_json" != "null" ]]; then
            extracted_key="$(printf '%s\n' "$item_json" | jq -r '(.login.password // "") + "\n" + (.notes // "") + "\n" + (([.fields[]?.value] // []) | join("\n"))' 2>/dev/null | grep -oE 'AGE-SECRET-KEY-1[0-9A-Z]+' | head -n1 || true)"
            if [[ -n "$extracted_key" ]]; then
                mkdir -p "$(dirname "$AGE_KEY")"
                printf '%s\n' "$extracted_key" > "$AGE_KEY"
                chmod 600 "$AGE_KEY"
                log "Age key restored from Bitwarden REST API to $AGE_KEY"
                return 0
            fi
        fi
    fi

    # Interactive check for CLI prompt if REST API didn't succeed
    [[ -n "${CI:-}" ]] && return 1
    [[ -r /dev/tty && -w /dev/tty ]] || return 1

    printf "Restore age key from Bitwarden CLI (item '%s')? [y/N] " "$BW_KEY_ITEM" > /dev/tty
    local ans; read -r ans < /dev/tty
    [[ "$ans" == "y" || "$ans" == "Y" ]] || return 1

    ensure_bw || { warn "Could not install bitwarden-cli."; return 1; }

    local bw_status
    bw_status="$(bw status 2>/dev/null | jq -r '.status // empty' 2>/dev/null || true)"
    if [[ "$bw_status" != "unlocked" ]]; then
        export BW_SESSION
        if [[ "$bw_status" == "locked" ]]; then
            BW_SESSION="$(bw unlock --raw < /dev/tty)" || return 1
        else
            BW_SESSION="$(bw login --raw < /dev/tty)" || return 1
        fi
    fi
    bw sync >/dev/null 2>&1 || true

    local raw_item
    raw_item="$(bw get item "$BW_KEY_ITEM" 2>/dev/null)" || raw_item=""
    if [[ -n "$raw_item" ]]; then
        extracted_key="$(printf '%s\n' "$raw_item" | jq -r '(.login.password // "") + "\n" + (.notes // "") + "\n" + (([.fields[]?.value] // []) | join("\n"))' 2>/dev/null | grep -oE 'AGE-SECRET-KEY-1[0-9A-Z]+' | head -n1 || true)"

        # Check attachments if not found in fields
        if [[ -z "$extracted_key" ]]; then
            local item_id
            item_id="$(printf '%s' "$raw_item" | jq -r '.id // empty' 2>/dev/null || true)"
            if [[ -n "$item_id" ]]; then
                local att_name
                while IFS= read -r att_name; do
                    [[ -z "$att_name" ]] && continue
                    local att_content
                    att_content="$(bw get attachment "$att_name" --itemid "$item_id" --raw 2>/dev/null || true)"
                    extracted_key="$(printf '%s\n' "$att_content" | grep -oE 'AGE-SECRET-KEY-1[0-9A-Z]+' | head -n1 || true)"
                    [[ -n "$extracted_key" ]] && break
                done < <(printf '%s' "$raw_item" | jq -r '.attachments[]?.fileName // empty' 2>/dev/null || true)
            fi
        fi

        if [[ -n "$extracted_key" ]]; then
            mkdir -p "$(dirname "$AGE_KEY")"
            printf '%s\n' "$extracted_key" > "$AGE_KEY"
            chmod 600 "$AGE_KEY"
            log "Age key restored from Bitwarden CLI to $AGE_KEY"
            return 0
        fi
    fi

    rm -f "$AGE_KEY"
    warn "Item '$BW_KEY_ITEM' found in vault but contains no valid AGE-SECRET-KEY-1."
    return 1
}

apply_args=(apply --force)
[[ -n "$REPO_ROOT" ]] && apply_args+=(--source "$REPO_ROOT")

if ! can_decrypt_secrets; then
    restore_age_key || true
fi

if ! can_decrypt_secrets; then
    warn "No working age key at $AGE_KEY — skipping encrypted secrets (~/.secrets/.private)."
    warn "Unlock Bitwarden (run 'bwu') or restore the key to $AGE_KEY (chmod 600), then run: make apply"
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
