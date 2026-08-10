# DevOps & Developer Dotfiles

[Bản tiếng Việt (Vietnamese version)](README.vn.md)

Professional environment configuration for **DevOps Engineers** and **Developers**, supporting cross-platform (**macOS** and **Linux/WSL**) managed with [chezmoi](https://chezmoi.io), [Homebrew](https://brew.sh/), and [mise](https://mise.jdx.dev/).

## Quick Setup

One command, both platforms — installs chezmoi to `~/.local/bin`, installs system packages (Linux), detects a missing age key (skips encrypted secrets with a clear warning instead of aborting), then applies everything:

```bash
curl -fsLS https://raw.githubusercontent.com/quyetmv/dotfiles/main/scripts/bootstrap.sh | bash

# then reload the shell (set terminal font to MesloLGS NF)
exec zsh -l
```

Secrets: to also get `~/.secrets/.private`, restore the age key to `~/.config/chezmoi/chezmoi_private_key` (chmod 600, from Bitwarden or another machine) **before** running bootstrap — or re-run `chezmoi apply` after restoring it.

### Non-interactive / pre-seeded init

Set these to skip prompts (useful for servers and CI):

| Env var | Effect |
|---------|--------|
| `CI=1` | Skip ALL prompts (uses defaults / env values below) |
| `CHEZMOI_GIT_EMAIL` / `CHEZMOI_GIT_NAME` / `CHEZMOI_GITHUB_USER` | Personal git identity |
| `CHEZMOI_WORK_GIT_DIR` / `CHEZMOI_WORK_GIT_EMAIL` / `CHEZMOI_WORK_GIT_NAME` | Work git identity (per-directory) |
| `CHEZMOI_ENABLE_SSH_KEYGEN=1` | Generate SSH key if missing |
| `CHEZMOI_ENABLE_DOCK=1` | Customize macOS Dock |
| `CHEZMOI_ENABLE_PERSONAL_APPS=1` | Personal macOS casks (EvKey/Telegram/Sublime Text) |
| `CHEZMOI_ENABLE_MAS_APPS=1` | Mac App Store apps via mas |

macOS-only questions (Dock, MAS, personal apps) are never asked on Linux.

### Manual fallback

```bash
# macOS
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply quyetmv/dotfiles

# Linux / WSL — packages must be installed BEFORE apply, otherwise the
# run_onchange chsh/font scripts skip once (no zsh yet) and never re-run
sudo apt update && sudo apt install -y curl git make
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init quyetmv/dotfiles
cd "$(~/.local/bin/chezmoi source-path)" && make linux
~/.local/bin/chezmoi apply
exec zsh -l
```

### Local checkout workflow

If you are modifying this repo and want to apply the current checkout content:

```bash
git clone git@github.com:quyetmv/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

`make install` uses [scripts/bootstrap.sh](/Users/quyetmv/workspace/dotfiles/scripts/bootstrap.sh#L1) to apply the current repo. If you want to bootstrap from a remote published repo instead of a local checkout, set `CHEZMOI_REPO=user/repo`.

## What gets installed

| Layer | macOS | Linux/WSL |
|-------|:-----:|:---------:|
| Homebrew formulas (CLI tools) | ✅ | — (no Linuxbrew; see apt/mise rows) |
| Casks (GUI apps) | ✅ | — |
| Personal macOS casks | Optional | — |
| Mac App Store apps (`mas`) | Optional | — |
| mise runtimes (kubectl, terraform, eza, zoxide, fastfetch, atuin...) | ✅ | ✅ |
| setup-linux.sh (apt: fzf, ripgrep, git, Docker...) | — | ✅ |

📋 Full tool list: [docs/devtools.md](docs/devtools.md)

## Daily usage

```bash
chezmoi update           # pull + apply latest changes
chezmoi diff && chezmoi apply
make sync                # after editing Brewfile.tmpl or dot_config/mise/config.toml
```

## DevOps Toolbox 🧰

These dotfiles integrate the most modern CLI tools to optimize workflow efficiency:

### [Powerlevel10k](https://github.com/romkatv/powerlevel10k) 🌟 (default prompt)
- **Features:**
  - Instant prompt: shell is usable before plugins finish loading.
  - DevOps-tuned config in `~/.p10k.zsh`: shows `k8s`, `tf`, `aws` only when relevant, distinct colors for `prod/stage/dev`.

### [Starship Prompt](https://starship.rs/) ✨ (opt-in)
- Installed but inactive by default — enable with `export DOTFILES_PROMPT=starship` before shell startup.
- Cross-shell prompt with DevOps context (K8s namespace, AWS profile, Terraform workspace) and `cmd_duration` alerts.

### [Atuin](https://atuin.sh/) 🕰️
- **Features:**
  - Replaces default history search with a SQLite database.
  - Search history by session or globally with an intuitive TUI.
  - Find complex Cloud/K8s commands incredibly fast with a user-friendly interface.

### [Zoxide](https://github.com/ajeetdsouza/zoxide) 🏎️
- **Features:**
  - A smarter `cd` command that learns your directory navigation habits.
  - Supports quick jumping to frequently accessed directories (`z <name_fragment>`).

### [Eza](https://eza.rocks/) 📁
- **Features:**
  - An upgrade to `ls` with icons, colors, and more visual metadata.
  - Integrates Git status right on the file/directory list.
  - Default aliases: `ls`, `ll`, `la`, `lt` (tree view).

### [Fastfetch](https://github.com/fastfetch-cli/fastfetch) ⚡
- **Features:**
  - Beautiful and fast display of system information (OS, Kernel, CPU, RAM...).
  - Modern replacement for `neofetch`.

### [Mise-en-place](https://mise.jdx.dev/) 🔧
- **Features:**
  - Manages versions for runtimes (Python, Go, Node) and DevOps tools (Kubectl, Terraform, Helm).
  - Automatically activates tool versions when entering a project directory via `.tool-versions`.

### [Lazygit](https://github.com/jesseduffield/lazygit) 🦥
- **Features:**
  - A godly TUI for Git. View logs, stage files, resolve conflicts with just a few shortcuts.
  - Integrates `delta` for beautiful and colorful diff displays.

### [K9s](https://k9scli.io/) ☸️
- **Features:**
  - The most powerful Terminal UI to manage Kubernetes clusters.
  - Monitor Pods, Logs, and Events in real-time without typing long commands.

### [fzf](https://github.com/junegunn/fzf) & [Ripgrep](https://github.com/BurntSushi/ripgrep) 🔎 heroes
- **Features:**
  - Fuzzy find files, directories, and history blazingly fast.
  - Search file contents at lightning speed with `rg`.
  - Content preview integration with `bat`.

---

## AI Agent Integration 🤖

This project is optimized to work alongside AI Coding Agents. The system applies a **High-Standard Engineering** philosophy: the AI should be direct, challenge false assumptions, prioritize accuracy, and remain extremely concise.

### AI Model Instructions

- **Claude (Claude Code/iTerm)**: Adheres to the instructions in `CLAUDE.md`. "High-Standard" mode is enabled by default.
- **Gemini (Desktop/IDE)**: Applies rules of high accuracy and thoroughly researches technical details before proposing solutions.
- **Codex / OpenAI**: Prioritizes pragmatic solutions, clean code, and immediately runnable results.

### Modular AI Skills 🧠

We build a modular knowledge system at `dot_agents/skills/` so AI can "read and deeply understand" your tech stack. Current skills:
- **`uv`**: Modern Python management standards.
- **`kubernetes`**: Best practices for resource management, Kustomize, and Helm.

---

## Dependency ownership

| Manifest | Managed |
|----------|---------|
| `Brewfile.tmpl` | Homebrew formulas, casks, Mac App Store |
| `dot_config/mise/config.toml` | mise settings + version-pinned runtimes and DevOps CLI tools (`[tools]`) |
| `dot_gitconfig.tmpl` + `dot_gitconfig-personal.tmpl` + `dot_gitconfig-work*.tmpl` | Git common config + personal/work identities |
| `dot_p10k.zsh` | Powerlevel10k prompt config inspired by the reference repo |
| `dot_zsh.d/*` | Ordered shell modules by group: env, navigation, git, node, docker, devops, python |
| `pyproject.toml` + `uv.lock` | Python deps (per project) |
| `private_dot_secrets/encrypted_private_dot_private.age` | Age-encrypted machine secrets, decrypts to `~/.secrets/.private` |
| `private_dot_ssh/private_conf.d/encrypted_bastions.age` | Age-encrypted SSH bastion ProxyJump config, decrypts to `~/.ssh/conf.d/bastions` |

## Machine-specific config

`.zshrc` sources, in order: `~/.secrets/.private`, then `~/.extra`, then `~/.functions`. Pick the right one:

### `~/.secrets/.private` — encrypted secrets (chezmoi + age)

For anything sensitive (API keys, tokens) that should still sync across your own machines via git. Managed by chezmoi, stored **age-encrypted** in the repo at `private_dot_secrets/encrypted_private_dot_private.age`, applied to `~/.secrets/.private` with mode `600`.

```bash
chezmoi edit ~/.secrets/.private   # decrypts, opens $EDITOR (nvim), re-encrypts on save
chezmoi apply                      # writes decrypted plaintext to ~/.secrets/.private
source ~/.secrets/.private          # or: exec zsh -l
```

Requires the age identity key at `~/.config/chezmoi/chezmoi_private_key` (its public recipient is baked into `.chezmoi.toml.tmpl`). **Back this key up** (e.g. Bitwarden) — without it the encrypted blob is unrecoverable. Bootstrap skips secrets with a warning if the key is missing; restore it and re-run `chezmoi apply`.

The encrypted blob is safe to commit/push (`git add private_dot_secrets/encrypted_private_dot_private.age`) — that's how it syncs to other machines holding the same age key.

### `~/.extra` / `~/.functions` — local-only, not tracked by git or chezmoi

For anything machine-local that never needs to sync or be encrypted (`.chezmoiignore`'d). Just create and edit directly:

```bash
touch ~/.extra
echo 'alias company="cd ~/workspace/company"' >> ~/.extra
source ~/.extra
```

### `~/.ssh/conf.d/bastions` — SSH ProxyJump config (age-encrypted, git-tracked)

Same mechanism as `~/.secrets/.private`: stored encrypted at `private_dot_ssh/private_conf.d/encrypted_bastions.age`, decrypts to `~/.ssh/conf.d/bastions`. Chosen over the old machine-local `[data]` prompt approach so entries get git history and sync across machines via the shared age key.

```bash
bastion-add <name> <range> <bastion-host>   # appends a Host block, then `chezmoi re-add`
bastion-list                                # grep Host lines in the applied file
chezmoi edit ~/.ssh/conf.d/bastions          # or edit freeform in $EDITOR

cd "$(chezmoi source-path)"
git add private_dot_ssh/private_conf.d/encrypted_bastions.age
git commit -m "..." && git push
```

`bastion-add`/`bastion-list` live in `dot_zsh.d/60-devops.zsh`. Skip the `jump-<name>` alias block automatically when `range` contains `*` (wildcard ranges can't be a `HostName`).

## Editing chezmoi-managed files & pushing back to git

`chezmoi edit <target>` opens the **source** file, which lives inside this git working tree (`chezmoi source-path` == repo root). For encrypted targets (e.g. `~/.secrets/.private`) it decrypts to a temp buffer and re-encrypts back into the source tree on save. Chezmoi never auto-commits — after editing, go commit like normal:

```bash
cd "$(chezmoi source-path)"
git status
git add <file>
git commit -m "..."
git push
```

Non-encrypted templated files (e.g. `dot_zshrc.tmpl`) can also just be edited directly in the repo with any editor — `chezmoi edit` is only needed to get the *decrypted* view of an encrypted target.


Git work identity can be enabled via env vars when applying:

```bash
CHEZMOI_WORK_GIT_DIR="~/workspace/company/" \
CHEZMOI_WORK_GIT_NAME="Your Work Name" \
CHEZMOI_WORK_GIT_EMAIL="you@company.com" \
CHEZMOI_WORK_GITHUB_USER="company-gh-user" \
chezmoi apply --source="$PWD" --force
```

*(Note: The above method is for manual override. For standard setup, simply run `chezmoi init` and answer the prompts for interactive multi-work identity configuration).*

## Runtime management

Node, Go, Python, and DevOps CLIs are all managed via `mise`.

After sync/apply:

```bash
exec zsh -l
mise install
node --version
go version
uv --version
```

Change default text globally:

```bash
mise use --global node@22
mise use --global go@1.24
```

Pin version for a specific project:

```bash
mise use node@22
mise use go@1.24
```

`mise` also supports reading familiar version files like `.nvmrc`, `.node-version`, `.go-version`.

## Python and uv

This repo only installs `python` and `uv` binaries via `mise`. It does not auto-create a global virtualenv.

After sync/apply:

```bash
exec zsh -l
command -v uv
uv --version
```

Within each Python project:

```bash
uv venv
uv lock
uv sync
uv run python ...
```

The repo also intentionally manages a shared Python workspace for DevOps tooling at `~/.devops-env`:

```bash
make devops-env
```

Or run manually:

```bash
cd ~/.devops-env
uv sync
```

The venv `bin` directory is already on `PATH`, and `make devops-env` enables auto-activation for new zsh shells. To enter it explicitly, run `devenv-activate`. To disable auto-activation, run `devenv-auto-off`.

## Validation

```bash
make test               # repo-side checks
make validate           # post-apply checks
```

## Reference clones

The `dotfiles/` directory in the root should only be used as a temporary reference repo. It is ignored by git and `chezmoi`, so it won't be applied to `$HOME`.

## Shell structure

`~/.zsh.d` is loaded in file name order, so the repo uses numeric prefixes for easy management:

- `10-env.zsh`: common env
- `20-navigation.zsh`: navigation and file utilities
- `30-git.zsh`: git aliases
- `40-node.zsh`: node/npm shortcuts
- `50-docker.zsh`: docker / docker compose
- `60-devops.zsh`: kubectl / terraform / helm / mise / calico (calicoctl, vendored at `bin/calicoctl`)
- `70-python.zsh`: `uv` workflow
- `80-modern-tools.zsh`: Starship, Atuin, Zoxide, Eza initialization
- `90-macos.zsh` / `90-linux.zsh`: OS-specific additions

The prompt theme is configured separately in `~/.p10k.zsh`.
This prompt is tuned for DevOps workflows: it only shows `k8s`, `tf`, `aws` when the current command is relevant, and changes colors more distinctly for `prod/stage/dev`.

## Secrets Management (Bitwarden CLI) 🔐

Proxmox credentials are stored in Bitwarden and fetched on demand via `dot_zsh.d/60-devops.zsh`. Items follow the naming convention `proxmox-<cluster>`, with `login.username` = API URL and `login.password` = API token.

### Setup

```bash
bw login    # one-time device login
bwu         # unlock vault + start local REST server on localhost:8087
```

### Commands

| Command | Purpose |
|---|---|
| `bwu` | Unlock vault, `bw sync`, (re)start `bw serve` on `localhost:8087`. Needed when the daemon is down or locked. |
| `pxlist` | List all `proxmox-*` clusters. |
| `bwuse <cluster>` | Export `PROXMOX_VE_URL` / `PROXMOX_VE_API_TOKEN` / `PROXMOX_CLUSTER`, and `GITLAB_TOKEN` if present. |
| `bwsshkey [key-name]` | Pull `ssh-<key-name>` (default `id_quyetmv`) to `~/.ssh/keys/<key-name>(.pub)`. |

`pxlist`/`bwuse`/`bwsshkey` all call `_bw_ensure` first: if `bw serve` is unlocked, it triggers a throttled (5 min) `POST /sync` on the running daemon so vault edits show up without re-running `bwu`. It only tells you to run `bwu` if the daemon is actually down or locked.

### Add a vault item

```bash
bw get template item \
  | jq '.type=1 | .name="proxmox-<cluster>" | .notes="" | .login.username="<api-url>" | .login.password="<api-token>"' \
  | bw encode | bw create item

pxlist   # auto-syncs bw serve and picks up the new item
```

### GitLab token

Single item, name `gitlab-token`, only `login.password` used. `bwuse <cluster>` picks it up automatically alongside the Proxmox credentials:

```bash
bw get template item \
  | jq '.type=1 | .name="gitlab-token" | .notes="" | .login.password="<personal-access-token>"' \
  | bw encode | bw create item

bwuse <cluster>   # exports PROXMOX_* and GITLAB_TOKEN together
```

### SSH key pair

Secure note, name `ssh-<key-name>` (default key name is `id_quyetmv`), key material in custom fields `private_key` / `public_key`. `bwsshkey` writes them to `~/.ssh/keys/<key-name>` (mode `600`) and `~/.ssh/keys/<key-name>.pub` (mode `644`):

```bash
bw get template item \
  | jq --rawfile priv ~/.ssh/keys/id_quyetmv --rawfile pub ~/.ssh/keys/id_quyetmv.pub \
      '.type=2 | .secureNote.type=0 | .name="ssh-id_quyetmv"
       | .fields=[{name:"private_key",value:$priv,type:0},{name:"public_key",value:$pub,type:0}]' \
  | bw encode | bw create item

bwsshkey            # pulls "ssh-id_quyetmv" -> ~/.ssh/keys/id_quyetmv(.pub)
bwsshkey other_key  # or any other "ssh-<name>" item -> ~/.ssh/keys/<name>(.pub)
```

## Commands

| Command | Purpose |
|---------|---------|
| `chezmoi managed` | List managed targets |
| `chezmoi diff` | Preview pending changes |
| `chezmoi apply` | Apply managed files |
| `chezmoi update` | Pull + apply |

## Acknowledgements

This project is inspired by and based on [Helder Burato Berto's dotfiles](https://github.com/helderberto/dotfiles).
