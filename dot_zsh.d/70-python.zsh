# Python and uv workflow
alias py="python"
alias urun="uv run"
alias usync="uv sync"
alias ulock="uv lock"
alias uvenv="uv venv"
alias upip="uv pip"
alias devenv='cd ~/.devops-env'
alias devenv-sync='cd ~/.devops-env && uv sync'
alias devenv-lock='cd ~/.devops-env && uv lock && chezmoi add ~/.devops-env/uv.lock'
alias devenv-run='cd ~/.devops-env && uv run python'

function devenv-activate() {
    local activate_script="${DEVOPS_ENV_DIR:-$HOME/.devops-env}/.venv/bin/activate"
    if [[ ! -r "$activate_script" ]]; then
        echo "✗ DevOps environment not found: $activate_script"
        echo "  Run: make devops-env"
        return 1
    fi
    source "$activate_script"
}

function devenv-auto-on() {
    local env_dir="${DEVOPS_ENV_DIR:-$HOME/.devops-env}"
    mkdir -p "$env_dir"
    touch "$env_dir/.auto-activate"
    echo "✓ DevOps environment auto-activation enabled"
    [[ -z "${VIRTUAL_ENV:-}" ]] && devenv-activate
}

function devenv-auto-off() {
    local env_dir="${DEVOPS_ENV_DIR:-$HOME/.devops-env}"
    rm -f "$env_dir/.auto-activate"
    echo "✓ DevOps environment auto-activation disabled"
    if [[ "${VIRTUAL_ENV:-}" == "$env_dir/.venv" ]] && command -v deactivate >/dev/null 2>&1; then
        deactivate
    fi
}

devenv_dir="${DEVOPS_ENV_DIR:-$HOME/.devops-env}"
if [[ -z "${VIRTUAL_ENV:-}" && ( -f "$devenv_dir/.auto-activate" || "${DEVOPS_ENV_AUTO_ACTIVATE:-0}" == "1" ) ]]; then
    devenv_activate_script="$devenv_dir/.venv/bin/activate"
    [[ -r "$devenv_activate_script" ]] && source "$devenv_activate_script"
    unset devenv_activate_script
fi
unset devenv_dir

# Add/remove packages and automatically sync back to dotfiles repo
function devenv-add() {
    (cd ~/.devops-env && uv add "$@" && chezmoi add ~/.devops-env/pyproject.toml ~/.devops-env/uv.lock 2>/dev/null || chezmoi add ~/.devops-env/pyproject.toml)
    echo "✓ Package(s) added and synced to dotfiles repo"
}

function devenv-remove() {
    (cd ~/.devops-env && uv remove "$@" && chezmoi add ~/.devops-env/pyproject.toml ~/.devops-env/uv.lock 2>/dev/null || chezmoi add ~/.devops-env/pyproject.toml)
    echo "✓ Package(s) removed and synced to dotfiles repo"
}
