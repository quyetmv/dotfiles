# DevOps & Developer Dotfiles

[Bản tiếng Việt (Vietnamese version)](README.vn.md)

Professional environment configuration for **DevOps Engineers** and **Developers**, supporting cross-platform (**macOS** and **Linux/WSL**) managed with [chezmoi](https://chezmoi.io), [Homebrew](https://brew.sh/), and [mise](https://mise.jdx.dev/).

## Quick Setup

### macOS

```bash
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply quyetmv/dotfiles
```

### Linux / WSL

```bash
sudo apt update && sudo apt install -y curl git make
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply quyetmv/dotfiles

# Then install system packages:
cd ~/.local/share/chezmoi && make linux

# Then reload shell and set terminal font to MesloLGS NF
exec zsh -l
```

### Optional flags

```bash
CHEZMOI_ENABLE_SSH_KEYGEN=1   # generate SSH key if missing
CHEZMOI_ENABLE_DOCK=1         # customize macOS Dock
CHEZMOI_ENABLE_PERSONAL_APPS=1 # install personal macOS casks like EvKey/Telegram/Sublime Text
CHEZMOI_ENABLE_MAS_APPS=1      # install Mac App Store apps via mas
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
| Homebrew formulas (CLI tools) | ✅ | ✅ (Linuxbrew) |
| Casks (GUI apps) | ✅ | — |
| Personal macOS casks | Optional | — |
| Mac App Store apps (`mas`) | Optional | — |
| mise runtimes (kubectl, terraform...) | ✅ | ✅ |
| setup-linux.sh (apt, Docker) | — | ✅ |

📋 Full tool list: [docs/devtools.md](docs/devtools.md)

## Daily usage

```bash
chezmoi update           # pull + apply latest changes
chezmoi diff && chezmoi apply
make sync                # after editing Brewfile.tmpl or dot_tool-versions
```

## DevOps Toolbox 🧰

These dotfiles integrate the most modern CLI tools to optimize workflow efficiency:

### [Starship Prompt](https://starship.rs/) 🌟
- **Features:**
  - Blazing fast prompt, smartly displaying DevOps context (K8s namespace, AWS profile, Terraform workspace).
  - Built-in real-time alerts when commands take too long (`cmd_duration`).
  - Highly customizable, displays standard Nerd Fonts icons.

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
| `dot_tool-versions` | Version-pinned runtimes and DevOps CLI tools via mise |
| `dot_config/mise/config.toml` | mise settings only, does not declare tool versions |
| `dot_gitconfig.tmpl` + `dot_gitconfig-personal.tmpl` + `dot_gitconfig-work*.tmpl` | Git common config + personal/work identities |
| `dot_p10k.zsh` | Powerlevel10k prompt config inspired by the reference repo |
| `dot_zsh.d/*` | Ordered shell modules by group: env, navigation, git, node, docker, devops, python |
| `pyproject.toml` + `uv.lock` | Python deps (per project) |

## Machine-specific config

During your daily work, you may have sensitive environment variables (API Keys, Tokens) or specific configurations that you only want to use on your current machine without committing them to GitHub.

This dotfiles repository is configured to **ignore** the `~/.private` file from Git. You can use this file to securely store your personal and work secrets.

**How to use:**

1. Create the file on your machine (only once):
   ```bash
   touch ~/.private
   ```
2. Add your content to the file (using nano, vim, or VSCode):
   ```bash
   # Example in ~/.private
   export WORK_API_KEY="secret123"
   export AWS_PROFILE="production"
   alias company="cd ~/workspace/company"
   ```
3. Zsh will automatically load (`source`) this file whenever you open a Terminal. To apply it immediately, run:
   ```bash
   source ~/.private
   ```


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
chezmoi apply --source="$PWD" --force
make devops-env
```

Or run manually:

```bash
cd ~/.devops-env
uv sync
```

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
- `60-devops.zsh`: kubectl / terraform / helm / mise
- `70-python.zsh`: `uv` workflow
- `80-modern-tools.zsh`: Starship, Atuin, Zoxide, Eza initialization
- `90-macos.zsh` / `90-linux.zsh`: OS-specific additions

The prompt theme is configured separately in `~/.p10k.zsh`.
This prompt is tuned for DevOps workflows: it only shows `k8s`, `tf`, `aws` when the current command is relevant, and changes colors more distinctly for `prod/stage/dev`.

## Commands

| Command | Purpose |
|---------|---------|
| `chezmoi managed` | List managed targets |
| `chezmoi diff` | Preview pending changes |
| `chezmoi apply` | Apply managed files |
| `chezmoi update` | Pull + apply |

## Acknowledgements

This project is inspired by and based on [Helder Burato Berto's dotfiles](https://github.com/helderberto/dotfiles).

