#!/usr/bin/env bash
set -euo pipefail

CHEZMOI_SOURCE="${CHEZMOI_SOURCE:-$PWD}"
ERRORS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }

# Locate chezmoi binary
if command -v chezmoi >/dev/null 2>&1; then
    CHEZMOI=chezmoi
elif [[ -x "$CHEZMOI_SOURCE/bin/chezmoi" ]]; then
    CHEZMOI="$CHEZMOI_SOURCE/bin/chezmoi"
elif [[ -x /tmp/bin/chezmoi ]]; then
    CHEZMOI=/tmp/bin/chezmoi
else
    echo "✗ chezmoi not found"
    exit 1
fi

echo "Testing Chezmoi Configuration"
echo "=============================="

echo ""
echo "1) chezmoi doctor"
doctor_output="$("$CHEZMOI" doctor --source "$CHEZMOI_SOURCE" 2>&1 || true)"
doctor_errors="$(printf '%s\n' "$doctor_output" | grep -E '^(failed|error)[[:space:]]' || true)"
doctor_errors="$(printf '%s\n' "$doctor_errors" | grep -Ev 'latest-version|hardlink' || true)"
if [[ -z "$doctor_errors" ]]; then
    pass "health check passed"
else
    fail "health check failed"
    echo "$doctor_errors"
fi

echo ""
echo "2) template rendering"
while IFS= read -r -d '' tmpl; do
    if $CHEZMOI execute-template --source "$CHEZMOI_SOURCE" < "$tmpl" >/dev/null 2>&1; then
        pass "$(basename "$tmpl")"
    else
        fail "$(basename "$tmpl") - template error"
    fi
done < <(find "$CHEZMOI_SOURCE" \
    \( -name "*.tmpl" \) \
    -not -path "*/dot_claude/*" \
    -not -path "*/references/*" \
    -not -path "*/.git/*" \
    -not -name ".chezmoi.toml.tmpl" \
    -print0)

echo ""
echo "3) shell syntax"
if zsh -n "$CHEZMOI_SOURCE/dot_p10k.zsh" 2>/dev/null; then
    pass "dot_p10k.zsh"
else
    fail "dot_p10k.zsh - syntax error"
fi

while IFS= read -r -d '' script; do
    if [[ "$script" == *.tmpl ]]; then
        rendered_script="$(mktemp)"
        if $CHEZMOI execute-template --source "$CHEZMOI_SOURCE" < "$script" >"$rendered_script" 2>/dev/null && zsh -n "$rendered_script" 2>/dev/null; then
            pass "$(basename "$script")"
        else
            fail "$(basename "$script") - zsh syntax error"
        fi
        rm -f "$rendered_script"
    elif zsh -n "$script" 2>/dev/null; then
        pass "$(basename "$script")"
    else
        fail "$(basename "$script") - zsh syntax error"
    fi
done < <(find "$CHEZMOI_SOURCE" \
    \( -path "$CHEZMOI_SOURCE/dot_zsh.d/*.zsh" -o -path "$CHEZMOI_SOURCE/dot_zsh.d/*.tmpl" -o -name "dot_zshrc.tmpl" -o -name "dot_zprofile.tmpl" \) \
    -not -path "*/references/*" \
    -not -path "*/.git/*" \
    -print0)

while IFS= read -r -d '' script; do
    if [[ "$script" == *.tmpl ]]; then
        rendered_script="$(mktemp)"
        if $CHEZMOI execute-template --source "$CHEZMOI_SOURCE" < "$script" >"$rendered_script" 2>/dev/null && bash -n "$rendered_script" 2>/dev/null; then
            pass "$(basename "$script")"
        else
            fail "$(basename "$script") - syntax error"
        fi
        rm -f "$rendered_script"
    elif bash -n "$script" 2>/dev/null; then
        pass "$(basename "$script")"
    else
        fail "$(basename "$script") - syntax error"
    fi
done < <(find "$CHEZMOI_SOURCE" \
    \( -name "*.sh" -o -name "*.sh.tmpl" \) \
    -not -path "*/dot_claude/*" \
    -not -path "*/references/*" \
    -not -path "*/.git/*" \
    -not -path "*/.github/*" \
    -print0)

echo ""
echo "4) required files"
REQUIRED_FILES=(
    "Brewfile.tmpl"
    "dot_gitconfig.tmpl"
    "dot_gitconfig-personal.tmpl"
    "dot_devops-env/pyproject.toml"
    "dot_devops-env/README.md"
    "dot_devops-env/dot_python-version"
    "dot_devops-env/dot_gitignore"
    "dot_p10k.zsh"
    "dot_zprofile.tmpl"
    "dot_zshrc.tmpl"
    "dot_zsh.d/10-env.zsh.tmpl"
    "dot_zsh.d/20-navigation.zsh"
    "dot_zsh.d/30-git.zsh"
    "dot_zsh.d/40-node.zsh"
    "dot_zsh.d/50-docker.zsh"
    "dot_zsh.d/60-devops.zsh"
    "dot_zsh.d/70-python.zsh"
    "dot_zsh.d/90-macos.zsh.tmpl"
    "dot_zsh.d/90-linux.zsh.tmpl"
    "dot_tmux.conf"
    "dot_tool-versions"
    "dot_config/uv/uv.toml"
    "dot_config/mise/config.toml"
    ".chezmoiignore"
    ".chezmoi.toml.tmpl"
    "scripts/bootstrap-devops-env.sh"
    "scripts/sync-tooling.sh"
)
for file in "${REQUIRED_FILES[@]}"; do
    if [ -e "$CHEZMOI_SOURCE/$file" ]; then
        pass "$file"
    else
        fail "$file missing"
    fi
done

echo ""
echo "5) script permissions"
while IFS= read -r -d '' script; do
    if [ -x "$script" ]; then
        pass "$(basename "$script") is executable"
    else
        fail "$(basename "$script") not executable"
    fi
done < <(find "$CHEZMOI_SOURCE/.chezmoiscripts" \( -name "run_once_*.sh*" -o -name "run_onchange_*.sh*" \) -print0)

PROJECT_SCRIPTS=(
    "scripts/bootstrap.sh"
    "scripts/bootstrap-devops-env.sh"
    "scripts/sync-tooling.sh"
)
for script in "${PROJECT_SCRIPTS[@]}"; do
    if [ -x "$CHEZMOI_SOURCE/$script" ]; then
        pass "$(basename "$script") is executable"
    else
        fail "$(basename "$script") not executable"
    fi
done

echo ""
echo "6) Brewfile template rendering"
if $CHEZMOI execute-template --source "$CHEZMOI_SOURCE" < "$CHEZMOI_SOURCE/Brewfile.tmpl" >/dev/null 2>&1; then
    pass "Brewfile.tmpl renders correctly"
else
    fail "Brewfile.tmpl rendering failed"
fi

echo ""
echo "7) dry-run apply to temp destination"
tmp_home="$(mktemp -d)"
tmp_state="$tmp_home/chezmoi-state.boltdb"
tmp_config="$(mktemp).toml"
# Provide minimal config so chezmoi doesn't fail on missing encryption key.
# Encrypted files are skipped in CI since the age key is not available.
printf '[data]\n  email = "ci@example.com"\n  name = "CI"\n  github_user = "ci"\n  work_configs = []\n  ssh_bastions = []\n  enable_dock = false\n  enable_mas_apps = false\n  enable_personal_apps = false\n  enable_ssh_keygen = false\n' > "$tmp_config"
if $CHEZMOI apply \
    --dry-run \
    --force \
    --no-tty \
    --exclude=encrypted \
    --source "$CHEZMOI_SOURCE" \
    --destination "$tmp_home" \
    --config "$tmp_config" \
    --persistent-state "$tmp_state" \
    >/dev/null 2>&1; then
    pass "chezmoi apply --dry-run succeeded"
else
    fail "chezmoi apply --dry-run failed"
fi
rm -rf "$tmp_home"
rm -f "$tmp_state" "$tmp_config"

echo ""
echo "8) secrets scan"
# Detect literal secret values, not keyword mentions (variable names, comments):
#  - quoted literal (8+ chars, not a $var or <placeholder> or {{template}}) assigned to a secret-ish name
#  - PEM private key headers
#  - well-known token prefixes (GitLab, GitHub, OpenAI-style, AWS access key, Slack)
SECRET_PATTERNS="(password|passwd|secret|token|api[_-]?key)['\"]?[[:space:]]*[:=][[:space:]]*['\"][^'\"\$<{][^'\"]{7,}|BEGIN [A-Z ]*PRIVATE KEY|glpat-[A-Za-z0-9_-]{10,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}"
if command -v rg >/dev/null 2>&1; then
    SECRETS="$(rg -nI -uu -i -e "$SECRET_PATTERNS" "$CHEZMOI_SOURCE" \
        --glob '!dot_claude/**' \
        --glob '!dotfiles/**' \
        --glob '!references/**' \
        --glob '!.git/**' \
        --glob '!.github/**' \
        --glob '!.neuralmemory/**' \
        --glob '!.gstack/**' \
        --glob '!.claude/**' \
        --glob '!docs/**' \
        --glob '!bin/chezmoi' \
        --glob '!*.md' \
        --glob '!.chezmoiignore' \
        --glob '!.gitignore' \
        --glob '!scripts/**' \
        --glob '!.chezmoiscripts/**' \
        --glob '!ansible.cfg' \
        | rg -v 'keybind|keyboard|keyword|AWS_OKTA_MFA_DUO_DEVICE=token|1password|password prompt|passwordless|NOPASSWD|chezmoi_private_key|\.secrets/\.private' || true)"
else
    SECRETS="$(grep -r -i -E "$SECRET_PATTERNS" "$CHEZMOI_SOURCE" \
        --exclude-dir=dot_claude \
        --exclude-dir=dotfiles \
        --exclude-dir=references \
        --exclude-dir=.github \
        --exclude-dir=.git \
        --exclude-dir=.neuralmemory \
        --exclude-dir=.gstack \
        --exclude-dir=.claude \
        --exclude-dir=docs \
        --exclude="*.md" \
        --exclude=".chezmoiignore" \
        --exclude=".gitignore" \
        --exclude-dir="scripts" \
        --exclude-dir=".chezmoiscripts" \
        --exclude="ansible.cfg" \
        --exclude="chezmoi" \
        | grep -v 'keybind\|keyboard\|keyword\|AWS_OKTA_MFA_DUO_DEVICE=token\|1password\|password prompt\|passwordless\|NOPASSWD\|chezmoi_private_key\|\.secrets/\.private' || true)"

fi

if [ -n "$SECRETS" ]; then
    fail "potential secrets found:"
    echo "$SECRETS"
else
    pass "no secrets detected"
fi

echo ""
echo "=============================="
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All tests passed${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS test(s) failed${NC}"
    exit 1
fi
