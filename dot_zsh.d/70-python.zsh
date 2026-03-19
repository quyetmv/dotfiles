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

# Add/remove packages and automatically sync back to dotfiles repo
function devenv-add() {
    (cd ~/.devops-env && uv add "$@" && chezmoi add ~/.devops-env/pyproject.toml ~/.devops-env/uv.lock 2>/dev/null || chezmoi add ~/.devops-env/pyproject.toml)
    echo "✓ Package(s) added and synced to dotfiles repo"
}

function devenv-remove() {
    (cd ~/.devops-env && uv remove "$@" && chezmoi add ~/.devops-env/pyproject.toml ~/.devops-env/uv.lock 2>/dev/null || chezmoi add ~/.devops-env/pyproject.toml)
    echo "✓ Package(s) removed and synced to dotfiles repo"
}
