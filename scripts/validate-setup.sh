#!/usr/bin/env bash
# Validate dotfiles setup after applying — cross-platform (macOS + Linux)

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
OS="$(uname -s)"

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; WARNINGS=$((WARNINGS + 1)); }

echo "🔍 Validating Dotfiles Setup ($OS)"
echo "============================="
echo ""

# 1. Git config
echo "1️⃣  Git configuration..."
if git config --get user.name >/dev/null 2>&1; then
    pass "user.name: $(git config --get user.name)"
else
    warn "user.name not set"
fi
if git config --get user.email >/dev/null 2>&1; then
    pass "user.email: $(git config --get user.email)"
else
    warn "user.email not set"
fi

# 2. Shell
echo ""
echo "2️⃣  Shell configuration..."
[[ -f "$HOME/.zshrc" ]]    && pass "~/.zshrc"    || fail "~/.zshrc not found"
[[ -f "$HOME/.p10k.zsh" ]] && pass "~/.p10k.zsh" || fail "~/.p10k.zsh not found"
[[ -d "$HOME/.zsh.d" ]]    && pass "~/.zsh.d"    || fail "~/.zsh.d not found"
[[ -f "$HOME/.zsh.d/10-env.zsh" ]] && pass "~/.zsh.d/10-env.zsh" || fail "~/.zsh.d/10-env.zsh not found"
[[ -f "$HOME/.zsh.d/60-devops.zsh" ]] && pass "~/.zsh.d/60-devops.zsh" || fail "~/.zsh.d/60-devops.zsh not found"
[[ -f "$HOME/.zsh.d/70-python.zsh" ]] && pass "~/.zsh.d/70-python.zsh" || fail "~/.zsh.d/70-python.zsh not found"

if [[ "$OS" == "Darwin" ]]; then
    [[ -f "$HOME/.zprofile" ]] && pass "~/.zprofile" || fail "~/.zprofile not found"
fi

if [[ "${SHELL:-}" == *"zsh" ]]; then
    pass "default shell: ${SHELL}"
else
    warn "default shell is not zsh: ${SHELL:-unknown}"
fi

# 3. Cross-platform tools
echo ""
echo "3️⃣  Core tools..."
CORE_TOOLS=("mise" "git" "nvim" "tmux" "fzf" "zsh")
if [[ "$OS" == "Darwin" ]]; then
    CORE_TOOLS=("brew" "${CORE_TOOLS[@]}")
fi
for tool in "${CORE_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 && pass "$tool" || fail "$tool not found"
done

# 4. mise-managed tools
echo ""
echo "4️⃣  mise-managed tools..."
MISE_TOOLS=("python" "uv" "jq" "yq" "kubectl" "helm" "terraform")
for tool in "${MISE_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 && pass "$tool" || warn "$tool not found (run: mise install)"
done

# 5. Workspace
echo ""
echo "5️⃣  Workspace directories..."
[[ -d "$HOME/workspace" ]] && pass "~/workspace" || warn "~/workspace missing"

# 6. Runtime manifests
echo ""
echo "6️⃣  Runtime manifests..."
[[ -f "$HOME/.tool-versions" ]]       && pass "~/.tool-versions"       || fail "~/.tool-versions missing"
[[ -f "$HOME/.config/uv/uv.toml" ]]  && pass "~/.config/uv/uv.toml"  || warn "~/.config/uv/uv.toml not found"
[[ -f "$HOME/.config/mise/config.toml" ]] && pass "~/.config/mise/config.toml" || warn "~/.config/mise/config.toml not found"
[[ -f "$HOME/.devops-env/pyproject.toml" ]] && pass "~/.devops-env/pyproject.toml" || warn "~/.devops-env/pyproject.toml not found"
[[ -f "$HOME/.devops-env/.python-version" ]] && pass "~/.devops-env/.python-version" || warn "~/.devops-env/.python-version not found"
[[ -d "$HOME/.devops-env/.venv" ]] && pass "~/.devops-env/.venv" || warn "~/.devops-env/.venv not found (run: make devops-env)"
[[ -f "$HOME/.private" ]]             && pass "~/.private"             || warn "~/.private not found"

# 7. OS-specific checks
echo ""
echo "7️⃣  OS-specific..."
if [[ "$OS" == "Darwin" ]]; then
    [[ -d "/Applications/iTerm.app" ]] || [[ -d "$HOME/Applications/iTerm.app" ]] \
        && pass "iTerm2 installed" || warn "iTerm2 not found"
    command -v mas >/dev/null 2>&1 && pass "mas (Mac App Store CLI)" || warn "mas not found"
elif [[ "$OS" == "Linux" ]]; then
    command -v docker >/dev/null 2>&1 && pass "Docker" || warn "Docker not found (run: ./scripts/setup-linux.sh)"
fi

# Summary
echo ""
echo "============================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ Setup validated!${NC}"
    [[ $WARNINGS -gt 0 ]] && echo -e "${YELLOW}⚠${NC}  $WARNINGS warning(s)"
    exit 0
else
    echo -e "${RED}❌ $ERRORS issue(s) found${NC}"
    [[ $WARNINGS -gt 0 ]] && echo -e "${YELLOW}⚠${NC}  $WARNINGS warning(s)"
    exit 1
fi
