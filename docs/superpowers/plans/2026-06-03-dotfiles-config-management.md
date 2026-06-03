# Dotfiles Config Management Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 7 issues in the dotfiles repo: track nvim config, fix nvim socket error, unify EDITOR, add interactive feature-flag prompts, convert run_once→run_onchange scripts, track Claude plugins, and remove the dead `lsd` dep.

**Architecture:** All changes are within the chezmoi-managed dotfiles repo. New scripts use `.tmpl` extension to embed content hashes that trigger re-runs when tracked files change. Feature flags use chezmoi's `promptBool` so values persist across `chezmoi apply` calls without re-prompting.

**Tech Stack:** chezmoi (dotfiles manager), Go templates (chezmoi templating), bash/zsh, lazy.nvim (nvim plugin manager), claude CLI

---

## File Map

| Action | Path |
|--------|------|
| Modify | `dot_zsh.d/10-env.zsh.tmpl` |
| Modify | `.chezmoi.toml.tmpl` |
| Modify | `Brewfile.tmpl` |
| Modify | `scripts/test-chezmoi.sh` |
| Create | `dot_config/nvim/` (via `chezmoi add`) |
| Create | `dot_claude/plugins/installed_plugins.json` (via `chezmoi add`) |
| Create | `.chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl` |
| Create | `.chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl` |
| Rename | `.chezmoiscripts/run_once_after_chsh.sh.tmpl` → `run_onchange_after_chsh.sh.tmpl` |
| Rename | `.chezmoiscripts/run_once_after_directories.sh` → `run_onchange_after_directories.sh` |
| Rename | `.chezmoiscripts/run_once_after_dock.sh.tmpl` → `run_onchange_after_dock.sh.tmpl` |
| Rename | `.chezmoiscripts/run_once_after_ssh.sh.tmpl` → `run_onchange_after_ssh.sh.tmpl` |
| Rename | `.chezmoiscripts/run_once_before_homebrew.sh.tmpl` → `run_onchange_before_homebrew.sh.tmpl` |
| Rename | `.chezmoiscripts/run_once_before_packages.sh.tmpl` → `run_onchange_before_packages.sh.tmpl` |

---

## Task 1: Confirm Baseline

**Files:** `scripts/test-chezmoi.sh` (read-only)

- [ ] **Step 1: Run the test suite**

```bash
make test
```

Expected: `All tests passed` (0 failures). If there are failures, fix them before proceeding.

- [ ] **Step 2: Note current test output for comparison**

Keep the output in mind — every subsequent task should leave `make test` green.

---

## Task 2: Fix EDITOR and nvim Socket Error

**Files:**
- Modify: `dot_zsh.d/10-env.zsh.tmpl`

- [ ] **Step 1: Replace the editor and add socket env var**

Replace the top two lines of `dot_zsh.d/10-env.zsh.tmpl`:

Old:
```bash
# vim as default
export EDITOR="vim"
export VISUAL="$EDITOR"
```

New:
```bash
export EDITOR="nvim"
export VISUAL="$EDITOR"
export NVIM_LISTEN_ADDRESS="$HOME/.cache/nvim/nvim.pipe"
```

Root cause of the socket error: macOS sandboxes `/var/folders/` for socket creation in certain contexts. `~/.cache/nvim/` is user-owned and unrestricted.

- [ ] **Step 2: Verify zsh syntax**

```bash
zsh -n dot_zsh.d/10-env.zsh.tmpl
```

Expected: no output (no errors).

- [ ] **Step 3: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 4: Commit**

```bash
git add dot_zsh.d/10-env.zsh.tmpl
git commit -m "fix: set EDITOR=nvim and fix nvim socket permission error"
```

---

## Task 3: Add nvim Config to Dotfiles

**Files:**
- Create: `dot_config/nvim/` (many files via `chezmoi add`)

Note: `lazy-lock.json` is already in `.chezmoiignore` — chezmoi will skip it automatically.

- [ ] **Step 1: Add nvim config via chezmoi**

```bash
CHEZMOI_SOURCE_DIR=$(pwd)
bin/chezmoi add --source "$CHEZMOI_SOURCE_DIR" ~/.config/nvim
```

If `bin/chezmoi` is not available, use system chezmoi:
```bash
chezmoi add --source "$(pwd)" ~/.config/nvim
```

- [ ] **Step 2: Verify files were added**

```bash
ls dot_config/nvim/
```

Expected output includes: `init.lua  lua/  after/  ftdetect/  stylua.toml  README.md`

```bash
ls dot_config/nvim/lua/
```

Expected: `hbb/  plugins/`

- [ ] **Step 3: Verify lazy-lock.json was NOT added**

```bash
ls dot_config/nvim/lazy-lock.json 2>/dev/null && echo "ERROR: should be excluded" || echo "OK: excluded"
```

Expected: `OK: excluded`

- [ ] **Step 4: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 5: Commit**

```bash
git add dot_config/nvim/
git commit -m "feat: track nvim config in dotfiles"
```

---

## Task 4: Add nvim Plugin Bootstrap Script

**Files:**
- Create: `.chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl`

The script is a `.tmpl` file so that chezmoi embeds content hashes of key nvim config files. When those files change, the script content changes, causing chezmoi to re-run it.

- [ ] **Step 1: Create the script**

```bash
cat > .chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl << 'EOF'
#!/usr/bin/env bash
# Hashes below change when nvim config changes, triggering this script to re-run.
# init.lua:  {{ include (joinPath .chezmoi.sourceDir "dot_config/nvim/init.lua") | sha256sum }}
# lazy.lua:  {{ include (joinPath .chezmoi.sourceDir "dot_config/nvim/lua/hbb/lazy.lua") | sha256sum }}
# plugins:   {{ include (joinPath .chezmoi.sourceDir "dot_config/nvim/lua/plugins/init.lua") | sha256sum }}
set -euo pipefail
command -v nvim >/dev/null 2>&1 || exit 0
mkdir -p "$HOME/.cache/nvim"
nvim --headless +"Lazy! sync" +qa 2>/dev/null || true
EOF
```

- [ ] **Step 2: Make executable**

```bash
chmod +x .chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl
```

- [ ] **Step 3: Verify template renders without error**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl
```

Expected: rendered bash script with sha256 hashes in the comment lines (no template errors).

- [ ] **Step 4: Verify bash syntax on rendered output**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl | bash -n
```

Expected: no output (no errors).

- [ ] **Step 5: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 6: Commit**

```bash
git add .chezmoiscripts/run_onchange_after_nvim-plugins.sh.tmpl
git commit -m "feat: auto-sync nvim plugins when config changes"
```

---

## Task 5: Feature Flags → Interactive Prompts

**Files:**
- Modify: `.chezmoi.toml.tmpl`

Replace the four env-var-only feature flag lines with `promptBool` calls that also keep env var fallbacks for CI.

- [ ] **Step 1: Replace feature flag section**

In `.chezmoi.toml.tmpl`, find and replace this block (lines 65–68):

Old:
```
    enable_dock = {{ eq (env "CHEZMOI_ENABLE_DOCK") "1" }}
    enable_mas_apps = {{ eq (env "CHEZMOI_ENABLE_MAS_APPS") "1" }}
    enable_personal_apps = {{ eq (env "CHEZMOI_ENABLE_PERSONAL_APPS") "1" }}
    enable_ssh_keygen = {{ eq (env "CHEZMOI_ENABLE_SSH_KEYGEN") "1" }}
```

Also add the variable declarations near the top of the file, after the `{{- $interactive := ... }}` line (line 1). Insert after line 1:

```
{{- $enableDock := eq (env "CHEZMOI_ENABLE_DOCK") "1" -}}
{{- $enableMasApps := eq (env "CHEZMOI_ENABLE_MAS_APPS") "1" -}}
{{- $enablePersonalApps := eq (env "CHEZMOI_ENABLE_PERSONAL_APPS") "1" -}}
{{- $enableSshKeygen := eq (env "CHEZMOI_ENABLE_SSH_KEYGEN") "1" -}}
{{- if $interactive -}}
{{-   $enableDock = promptBool "Enable Dock customization? (macOS only)" -}}
{{-   $enableMasApps = promptBool "Enable Mac App Store apps?" -}}
{{-   $enablePersonalApps = promptBool "Enable personal apps (evkey, Telegram, etc.)?" -}}
{{-   $enableSshKeygen = promptBool "Generate SSH key?" -}}
{{- end -}}
```

Replace the `[data]` section lines for these flags with:
```
    enable_dock = {{ $enableDock }}
    enable_mas_apps = {{ $enableMasApps }}
    enable_personal_apps = {{ $enablePersonalApps }}
    enable_ssh_keygen = {{ $enableSshKeygen }}
```

The final `.chezmoi.toml.tmpl` should start with:
```
{{- $interactive := not (or (env "CI") (env "GITHUB_ACTIONS")) -}}
{{- $enableDock := eq (env "CHEZMOI_ENABLE_DOCK") "1" -}}
{{- $enableMasApps := eq (env "CHEZMOI_ENABLE_MAS_APPS") "1" -}}
{{- $enablePersonalApps := eq (env "CHEZMOI_ENABLE_PERSONAL_APPS") "1" -}}
{{- $enableSshKeygen := eq (env "CHEZMOI_ENABLE_SSH_KEYGEN") "1" -}}
{{- if $interactive -}}
{{-   $enableDock = promptBool "Enable Dock customization? (macOS only)" -}}
{{-   $enableMasApps = promptBool "Enable Mac App Store apps?" -}}
{{-   $enablePersonalApps = promptBool "Enable personal apps (evkey, Telegram, etc.)?" -}}
{{-   $enableSshKeygen = promptBool "Generate SSH key?" -}}
{{- end -}}

{{- $email := env "CHEZMOI_GIT_EMAIL" -}}
...
```

- [ ] **Step 2: Verify template renders in CI mode (non-interactive)**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
CI=1 "$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoi.toml.tmpl
```

Expected: renders valid TOML with `enable_dock = false` etc. (all false since no env vars set and not interactive).

- [ ] **Step 3: Verify template renders with env var overrides**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
CI=1 CHEZMOI_ENABLE_DOCK=1 CHEZMOI_GIT_EMAIL=test@test.com CHEZMOI_GIT_NAME="Test" CHEZMOI_GITHUB_USER=test "$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoi.toml.tmpl
```

Expected: `enable_dock = true` in the output.

- [ ] **Step 4: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 5: Commit**

```bash
git add .chezmoi.toml.tmpl
git commit -m "feat: add interactive prompts for feature flags"
```

---

## Task 6: Rename run_once → run_onchange Scripts

**Files:**
- Rename 6 scripts in `.chezmoiscripts/`
- Modify: `scripts/test-chezmoi.sh` (permission check pattern)

**Important:** On the next `chezmoi apply` after rename, chezmoi will treat these as new `run_onchange_` scripts (no prior state) and run them once. All scripts have idempotency guards, so this is safe.

- [ ] **Step 1: Rename all six scripts**

```bash
cd .chezmoiscripts
git mv run_once_after_chsh.sh.tmpl        run_onchange_after_chsh.sh.tmpl
git mv run_once_after_directories.sh       run_onchange_after_directories.sh
git mv run_once_after_dock.sh.tmpl         run_onchange_after_dock.sh.tmpl
git mv run_once_after_ssh.sh.tmpl          run_onchange_after_ssh.sh.tmpl
git mv run_once_before_homebrew.sh.tmpl    run_onchange_before_homebrew.sh.tmpl
git mv run_once_before_packages.sh.tmpl    run_onchange_before_packages.sh.tmpl
cd ..
```

- [ ] **Step 2: Update permission check pattern in test-chezmoi.sh**

In `scripts/test-chezmoi.sh`, find section 5 and update the `find` command.

Old:
```bash
done < <(find "$CHEZMOI_SOURCE/.chezmoiscripts" -name "run_once_*.sh*" -print0)
```

New:
```bash
done < <(find "$CHEZMOI_SOURCE/.chezmoiscripts" \( -name "run_once_*.sh*" -o -name "run_onchange_*.sh*" \) -print0)
```

- [ ] **Step 3: Verify renamed files are executable**

```bash
ls -la .chezmoiscripts/run_on*.sh* | awk '{print $1, $9}'
```

Expected: all files show `-rwxr-xr-x` (execute bit set).

If any are missing the execute bit:
```bash
chmod +x .chezmoiscripts/run_onchange_*.sh*
```

- [ ] **Step 4: Run tests**

```bash
make test
```

Expected: `All tests passed` — section 5 should now check all `run_onchange_` scripts.

- [ ] **Step 5: Commit**

```bash
git add .chezmoiscripts/ scripts/test-chezmoi.sh
git commit -m "refactor: convert run_once scripts to run_onchange for re-runnability"
```

---

## Task 7: Add Claude Plugins Tracking

**Files:**
- Create: `dot_claude/plugins/installed_plugins.json` (via `chezmoi add`)
- Create: `.chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl`

- [ ] **Step 1: Track installed_plugins.json**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" add --source "$(pwd)" ~/.claude/plugins/installed_plugins.json
```

- [ ] **Step 2: Verify the file was added**

```bash
ls dot_claude/plugins/installed_plugins.json
```

Expected: file exists.

```bash
python3 -c "import json; d=json.load(open('dot_claude/plugins/installed_plugins.json')); print(list(d['plugins'].keys()))"
```

Expected: list of plugin IDs like `['ui-ux-pro-max@ui-ux-pro-max-skill', 'superpowers@claude-plugins-official', ...]`

- [ ] **Step 3: Create the reinstall script**

```bash
cat > .chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl << 'EOF'
#!/usr/bin/env bash
# Re-runs when installed_plugins.json changes.
# plugins hash: {{ include (joinPath .chezmoi.sourceDir "dot_claude/plugins/installed_plugins.json") | sha256sum }}
set -euo pipefail
command -v claude >/dev/null 2>&1 || exit 0
PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$PLUGINS_JSON" ] || exit 0
# Keys are in "plugin@marketplace" format as required by `claude plugins install`
python3 - "$PLUGINS_JSON" <<'PYEOF'
import json, subprocess, sys
data = json.load(open(sys.argv[1]))
for plugin_id in data.get("plugins", {}):
    print(f"Installing {plugin_id}...")
    subprocess.run(["claude", "plugins", "install", plugin_id], check=False)
PYEOF
EOF
```

- [ ] **Step 4: Make executable**

```bash
chmod +x .chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl
```

- [ ] **Step 5: Verify template renders**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl
```

Expected: rendered script with sha256 hash in the comment, no template errors.

- [ ] **Step 6: Verify bash syntax**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" execute-template --source "$(pwd)" < .chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl | bash -n
```

Expected: no output (no errors).

- [ ] **Step 7: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 8: Commit**

```bash
git add dot_claude/plugins/installed_plugins.json .chezmoiscripts/run_onchange_after_install-claude-plugins.sh.tmpl
git commit -m "feat: track Claude plugins and auto-reinstall on new machines"
```

---

## Task 8: Remove Dead lsd Dependency

**Files:**
- Modify: `Brewfile.tmpl`

- [ ] **Step 1: Remove lsd from Brewfile.tmpl**

In `Brewfile.tmpl`, delete this line:
```
brew "lsd"
```

It appears in the core CLI section. `eza` covers all use cases and already has aliases in `80-modern-tools.zsh`.

- [ ] **Step 2: Verify Brewfile renders**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
"$CHEZMOI_EXE" execute-template --source "$(pwd)" < Brewfile.tmpl | grep lsd
```

Expected: no output (lsd no longer present).

- [ ] **Step 3: Run tests**

```bash
make test
```

Expected: `All tests passed`

- [ ] **Step 4: Commit**

```bash
git add Brewfile.tmpl
git commit -m "chore: remove lsd dead dependency (eza covers all use cases)"
```

---

## Task 9: Final Validation

**Files:** read-only

- [ ] **Step 1: Run full test suite**

```bash
make test
```

Expected: `All tests passed`, 0 failures.

- [ ] **Step 2: Dry-run apply**

```bash
CHEZMOI_EXE=$(command -v chezmoi 2>/dev/null || echo ./bin/chezmoi)
CI=1 CHEZMOI_GIT_NAME="Test" CHEZMOI_GIT_EMAIL="test@test.com" CHEZMOI_GITHUB_USER="test" \
  "$CHEZMOI_EXE" apply --dry-run --force --no-tty --source "$(pwd)"
```

Expected: lists files to be applied/updated, exits 0, no errors.

- [ ] **Step 3: Verify all new scripts have correct permissions**

```bash
find .chezmoiscripts -name "run_on*.sh*" -exec ls -la {} \; | awk '{print $1, $9}'
```

Expected: all files show `-rwxr-xr-x`.

- [ ] **Step 4: Verify nvim config structure**

```bash
find dot_config/nvim -type f | sort
```

Expected: lists all nvim config files, no `lazy-lock.json` present.

- [ ] **Step 5: Verify no run_once_ scripts remain**

```bash
ls .chezmoiscripts/run_once_* 2>/dev/null && echo "ERROR: run_once scripts remain" || echo "OK: all converted"
```

Expected: `OK: all converted`
