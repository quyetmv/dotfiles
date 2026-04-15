#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${DEVOPS_ENV_DIR:-$HOME/.devops-env}"

if [[ -d "$HOME/.local/share/mise/shims" ]]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
fi

if ! command -v uv >/dev/null 2>&1; then
    echo "✗ uv not found"
    echo "  Run: chezmoi apply --force"
    echo "  Then: exec zsh -l"
    exit 1
fi

if [[ ! -f "$PROJECT_DIR/pyproject.toml" ]]; then
    echo "✗ pyproject.toml not found in $PROJECT_DIR"
    echo "  Run: chezmoi apply to provision ~/.devops-env first"
    exit 1
fi

echo "🐍 Syncing DevOps Python environment in $PROJECT_DIR ..."
(
    cd "$PROJECT_DIR"
    uv sync
)
touch "$PROJECT_DIR/.auto-activate"

echo "✓ DevOps Python environment is ready"
echo "  Activate: source \"$PROJECT_DIR/.venv/bin/activate\""
echo "  Zsh helper: devenv-activate"
echo "  Auto-activate: enabled for new zsh shells"
echo "  Disable: devenv-auto-off"
echo "  Or run:   cd \"$PROJECT_DIR\" && uv run python"
