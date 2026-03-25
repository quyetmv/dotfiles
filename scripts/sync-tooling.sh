#!/usr/bin/env bash
# ============================================================================
# sync-tooling.sh — Sync packages and runtimes
#
# Usage:  ./sync-tooling.sh
#
# When to run:
#   - After editing Brewfile.tmpl (macOS: adding/removing brew packages or casks)
#   - After editing dot_tool-versions (adding/removing mise-managed tools)
#
# What it does:
#   - macOS: runs `brew bundle install` to sync Homebrew packages
#   - Both:  runs `mise install` to sync CLI tools from dot_tool-versions
#   - Both:  installs tmux plugin manager (tpm) if missing
# ============================================================================

set -euo pipefail

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TOOL_VERSIONS="$REPO_ROOT/dot_tool-versions"
BREWFILE_TMPL="$REPO_ROOT/Brewfile.tmpl"
OS="$(uname -s)"
TMP_ROOT="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if command -v chezmoi >/dev/null 2>&1; then
    CHEZMOI=chezmoi
elif [[ -x "$REPO_ROOT/bin/chezmoi" ]]; then
    CHEZMOI="$REPO_ROOT/bin/chezmoi"
else
    echo "✗ chezmoi is required to render Brewfile.tmpl"
    exit 1
fi

# --- Backup / Snapshot ---
BACKUP_DIR="$HOME/.dotfiles_backup"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

snapshot_state() {
    echo "📸 Creating pre-sync snapshot in $BACKUP_DIR..."
    # Snapshot mise
    [[ -f "$HOME/.tool-versions" ]] && cp "$HOME/.tool-versions" "$BACKUP_DIR/tool-versions.$TIMESTAMP"
    
    # Snapshot Homebrew (macOS)
    if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        brew bundle dump --file="$BACKUP_DIR/Brewfile.$TIMESTAMP" 2>/dev/null || echo "  ⚠ Could not dump Brewfile snapshot"
    fi

    # --- Rotation: Keep only the last 3 versions ---
    cleanup_old_snapshots() {
        local prefix="$1"
        local pattern="$2"
        (
            cd "$BACKUP_DIR"
            # Check if any files match the pattern before running ls
            # Use compgen or a simple loop/test to avoid ls error
            local files
            files=( $pattern )
            if [[ -e "${files[0]}" ]]; then
                # shellcheck disable=SC2012
                ls -t $pattern 2>/dev/null | tail -n +4 | xargs -r rm -f
            fi
        )
    }

    cleanup_old_snapshots "Brewfile" "Brewfile.*"
    cleanup_old_snapshots "tool-versions" "tool-versions.*"
}

snapshot_state

if [[ "$OS" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "✗ Homebrew is required on macOS"
        exit 1
    fi

    if [[ ! -f "$BREWFILE_TMPL" ]]; then
        echo "✗ Brewfile.tmpl not found: $BREWFILE_TMPL"
        exit 1
    fi

    BREWFILE="$TMP_ROOT/Brewfile"
    if ! "$CHEZMOI" execute-template --source "$REPO_ROOT" < "$BREWFILE_TMPL" > "$BREWFILE"; then
        echo "✗ Failed to render Brewfile.tmpl"
        exit 1
    fi

    if [[ ! -s "$BREWFILE" ]]; then
        echo "✗ Rendered Brewfile is empty"
        exit 1
    fi

    echo "📦 Syncing Homebrew bundle..."
    bundle_cmd=(brew bundle install --file "$BREWFILE" --no-upgrade)

    if ! command -v mas >/dev/null 2>&1 || ! mas account >/dev/null 2>&1; then
        echo "  → Mac App Store is not signed in, skipping mas entries"
        bundle_cmd=(env HOMEBREW_BUNDLE_MAS_SKIP=1 "${bundle_cmd[@]}")
    fi

    "${bundle_cmd[@]}"
else
    echo "ℹ Skipping Homebrew on Linux (use setup-linux.sh for apt packages)"
fi

# --- mise runtimes (cross-platform) ---
if ! command -v mise >/dev/null 2>&1; then
    if [[ -x "$HOME/.local/bin/mise" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo "✗ mise is required (install: curl https://mise.run | sh)"
        exit 1
    fi
fi

if [[ ! -f "$TOOL_VERSIONS" ]]; then
    echo "✗ dot_tool-versions not found: $TOOL_VERSIONS"
    exit 1
fi

MISE_TMP="$TMP_ROOT/mise"
mkdir -p "$MISE_TMP"
cp "$TOOL_VERSIONS" "$MISE_TMP/.tool-versions"

echo "🔧 Syncing mise runtimes..."
mise install --yes --cd "$MISE_TMP"

if [[ ! -f "$HOME/.tool-versions" ]] || ! cmp -s "$TOOL_VERSIONS" "$HOME/.tool-versions"; then
    echo "ℹ ~/.tool-versions is not in sync with this repo yet."
    echo "  Run: chezmoi apply --source \"$REPO_ROOT\" --force"
fi

echo "ℹ uv is installed as a mise-managed CLI tool."
echo "  It does not create a Python environment automatically."
echo "  Per-project workflow: uv venv / uv lock / uv sync / uv run ..."
echo "  If uv is not visible yet in your shell, reload it: exec zsh -l"

# --- tmux plugin manager ---
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    echo "🔌 Installing tmux plugin manager..."
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "✓ Tooling sync complete"
