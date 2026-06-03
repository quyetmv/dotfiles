# Dotfiles Config Management Optimization

**Date:** 2026-06-03  
**Status:** Approved

## Problem

Six distinct issues in the current dotfiles setup:

1. `~/.config/nvim` exists on-machine but is untracked by chezmoi — config lost on new machine
2. nvim socket error: `Failed to start server: operation not permitted` on `/var/folders/` (macOS sandbox)
3. `EDITOR="vim"` in `10-env.zsh.tmpl` but `.chezmoi.toml.tmpl` uses `nvim`
4. Feature flags (`enable_dock`, `enable_mas_apps`, `enable_personal_apps`, `enable_ssh_keygen`) only configurable via env vars; default to `false` on every re-apply
5. `run_once_*` scripts can't re-run when content changes, making iteration painful
6. `~/.claude/plugins/installed_plugins.json` untracked — plugins lost on new machine
7. `lsd` in Brewfile is a dead dep (only `eza` aliases defined)

## Architecture

All changes are within the chezmoi-managed dotfiles repo. No new external dependencies.

```
dotfiles/
├── .chezmoi.toml.tmpl          # feature flags → interactive prompts
├── .chezmoiignore              # lazy-lock.json already excluded
├── .chezmoiscripts/
│   ├── run_onchange_after_chsh.sh.tmpl          # renamed
│   ├── run_onchange_after_directories.sh         # renamed
│   ├── run_onchange_after_dock.sh.tmpl           # renamed
│   ├── run_onchange_after_install-claude-plugins.sh  # new
│   ├── run_onchange_after_nvim-plugins.sh        # new
│   ├── run_onchange_after_ssh.sh.tmpl            # renamed
│   ├── run_onchange_before_homebrew.sh.tmpl      # renamed
│   └── run_onchange_before_packages.sh.tmpl      # renamed
├── dot_claude/
│   └── plugins/
│       └── installed_plugins.json               # new: tracked
├── dot_config/
│   └── nvim/                                    # new: tracked (minus lazy-lock.json)
│       ├── init.lua
│       ├── lua/
│       ├── after/
│       ├── ftdetect/
│       └── stylua.toml
├── dot_zsh.d/
│   └── 10-env.zsh.tmpl                          # EDITOR + NVIM_LISTEN_ADDRESS fix
└── Brewfile.tmpl                                # remove lsd
```

## Components

### 1. nvim Config

**Action:** `chezmoi add ~/.config/nvim` (excludes `lazy-lock.json` via `.chezmoiignore`)

All nvim config files tracked as `dot_config/nvim/` in the repo.

### 2. nvim Error Fixes (`dot_zsh.d/10-env.zsh.tmpl`)

```bash
export EDITOR="nvim"
export VISUAL="$EDITOR"
export NVIM_LISTEN_ADDRESS="$HOME/.cache/nvim/nvim.pipe"
```

Root cause of socket error: macOS sandboxes `/var/folders/` for socket creation from some contexts. Redirecting to `~/.cache/nvim/` (user-owned) avoids the restriction.

### 3. nvim Plugin Bootstrap

**New file:** `.chezmoiscripts/run_onchange_after_nvim-plugins.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
command -v nvim >/dev/null 2>&1 || exit 0
mkdir -p "$HOME/.cache/nvim"
nvim --headless +"Lazy! sync" +qa 2>/dev/null || true
```

Triggered by chezmoi content-hash when `dot_config/nvim/` changes. The `|| true` prevents exit on non-critical lazy.nvim warnings.

### 4. Feature Flags → Interactive Prompts (`.chezmoi.toml.tmpl`)

```go
{{- $enableDock := false }}
{{- $enableMasApps := false }}
{{- $enablePersonalApps := false }}
{{- $enableSshKeygen := false }}
{{- if $interactive }}
{{-   $enableDock = promptBool "Enable Dock customization? (y/n)" }}
{{-   $enableMasApps = promptBool "Enable Mac App Store apps? (y/n)" }}
{{-   $enablePersonalApps = promptBool "Enable personal apps (evkey, telegram, etc.)? (y/n)" }}
{{-   $enableSshKeygen = promptBool "Generate SSH key? (y/n)" }}
{{- end }}
```

Values stored in chezmoi persistent data → not re-prompted on `chezmoi apply`, only on `chezmoi init`.

Env var fallbacks retained for CI.

### 5. run_once → run_onchange

All six `run_once_*` scripts renamed to `run_onchange_*`. Each script already has idempotency guards:

| Script | Guard |
|--------|-------|
| homebrew | `command -v brew` check |
| packages | `brew bundle --no-upgrade`, `mise install --yes` |
| chsh | `$SHELL != $ZSH_BIN` check |
| directories | `mkdir -p` + existence checks |
| ssh | `[ -f ~/.ssh/id_ed25519 ]` check |
| dock | `enable_dock` flag check |

Scripts trigger on content-hash change, not on every apply. Note: on first apply after rename, chezmoi treats them as new `run_onchange_` scripts (no prior state) and runs them once — idempotency guards make this safe.

### 6. Claude Plugins Tracking

**Track:** `dot_claude/plugins/installed_plugins.json`

**New file:** `.chezmoiscripts/run_onchange_after_install-claude-plugins.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
command -v claude >/dev/null 2>&1 || exit 0
PLUGINS_JSON="$HOME/.claude/plugins/installed_plugins.json"
[ -f "$PLUGINS_JSON" ] || exit 0
# Keys are already in "plugin@marketplace" format required by `claude plugins install`
python3 - "$PLUGINS_JSON" <<'EOF'
import json, subprocess, sys
data = json.load(open(sys.argv[1]))
for plugin_id in data.get("plugins", {}):
    print(f"Installing {plugin_id}...")
    subprocess.run(["claude", "plugins", "install", plugin_id], check=False)
EOF
```

### 7. Cleanup

Remove `brew "lsd"` from `Brewfile.tmpl`. No aliases reference it; `eza` covers all use cases.

### 8. Test Updates (`scripts/test-chezmoi.sh`)

- Update required files list: remove old `run_once_*` names, no new required files needed
- Script permission check: already scans `run_once_*.sh*` pattern — update to `run_on{once,change}_*.sh*`

## Error Handling

- nvim bootstrap: `|| true` prevents CI failure on plugin warnings
- Claude plugins: `check=False` — non-fatal if a plugin install fails
- All scripts: `set -euo pipefail` retained, guards exit cleanly on missing tools

## Testing

1. `make test` — runs `scripts/test-chezmoi.sh` (template rendering, shell syntax, permissions)
2. `make docker-test` — full validation in clean Docker container
3. Manual: `chezmoi apply --dry-run` on local machine
4. CI: GitHub Actions matrix (ubuntu-24.04, macos-15)
