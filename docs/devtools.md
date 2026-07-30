# DevOps Tools & Runtimes

Chi tiết về các tool được quản lý trong dotfiles.

## Ownership

- `dot_config/mise/config.toml`: source of truth cho `mise` settings + versions của runtimes và DevOps CLIs (`[tools]`)
- `Brewfile.tmpl`: source of truth cho Homebrew formulas, casks, và `mas`
- `dot_p10k.zsh`: Powerlevel10k prompt config lấy cảm hứng từ repo tham chiếu
- `dot_zsh.d/*`: shell modules được load theo thứ tự tên file

## mise (`dot_config/mise/config.toml`)

`mise` quản lý tất cả CLI tools có version, cài đặt tự động khi chạy `mise install`.
Danh sách tool + version đầy đủ nằm trong `[tools]` của `dot_config/mise/config.toml`
(không duplicate ra đây để tránh lệch phiên bản theo thời gian) — gồm 4 nhóm theo comment
trong file: core languages (node/python/go/uv), infrastructure & cloud (terraform/kubectl/helm/...),
Kubernetes tools (k9s/kubectx/kubens/kubecm), và versioned CLI utilities (jq/yq/shellcheck/...).

Lưu ý quan trọng: versions phải khai báo ở `~/.config/mise/config.toml` (global config thật
của mise, áp dụng bất kể cwd), không phải `~/.tool-versions` — file đó chỉ resolve được khi
cwd nằm trong `$HOME` hoặc thư mục con (mise đi ngược lên cây thư mục từ cwd, không bao giờ
"thấy" được file nằm ở thư mục con của cwd).

## Homebrew (`Brewfile.tmpl`)

### Cross-platform (macOS + Linuxbrew)
Shell tools: `fd`, `fzf`, `ripgrep`, `tmux`, `mise`, `chezmoi`, `powerlevel10k`, `zoxide`, zsh plugins, `mysql-client`, `redis` (`redis-cli`). (`bat`, `lazygit`, `jq`, `neovim`, `atuin` là mise-owned — xem `[tools]` trong `dot_config/mise/config.toml`.)

### macOS only (casks)
| App | Ghi chú |
|-----|---------|
| Antigravity | Utility app |
| DevToys | Developer utility toolbox |
| DBeaver Community | Database client |
| Docker Desktop | Container runtime |
| Chrome | Browser |
| iTerm2 | Terminal |
| Notion | Notes and workspace |
| NoSQLBooster for MongoDB | MongoDB client |
| pgAdmin 4 | PostgreSQL admin client |
| Slack | Chat |
| Todoist App | Task management |
| VS Code | Editor |
| Postman | API testing |
| Rectangle | Window manager |

### macOS optional personal casks (`CHEZMOI_ENABLE_PERSONAL_APPS=1`)
| App | Ghi chú |
|-----|---------|
| EvKey | Vietnamese input method |
| Sublime Text | Editor |
| Telegram | Messaging |

### Mac App Store optional apps (`CHEZMOI_ENABLE_MAS_APPS=1`)
| App | Ghi chú |
|-----|---------|
| Amphetamine | Keep-awake utility |
| The Unarchiver | Archive utility |

## Python Workflow

Python được quản lý bởi `mise`, package manager dùng `uv`:

```bash
uv lock        # Lock dependencies
uv sync        # Install dependencies
uv run python  # Run with project env
```

Dependencies của từng project nằm trong `pyproject.toml` + `uv.lock` riêng.
Dotfiles chỉ cài `uv` executable, không tự tạo virtualenv dùng chung cho cả máy.

Ngoài ra repo này provision sẵn `~/.devops-env` như một Python workspace riêng cho DevOps scripts:

- `~/.devops-env/pyproject.toml`
- `~/.devops-env/.python-version`
- `make devops-env` để apply dotfiles, chạy `uv sync`, và bật auto-activate cho zsh shell mới

Global shell shortcuts cho Python nằm ở `dot_zsh.d/70-python.zsh`:

- `uvenv` -> `uv venv`
- `ulock` -> `uv lock`
- `usync` -> `uv sync`
- `urun` -> `uv run`
- `devenv` -> `cd ~/.devops-env`
- `devenv-sync` -> sync `~/.devops-env`
- `devenv-activate` -> activate `~/.devops-env/.venv`
- `devenv-auto-off` -> tắt auto-activate

## Shell modules

| Module | Mục đích |
|--------|----------|
| `10-env.zsh` | editor, locale, env helpers |
| `20-navigation.zsh` | navigation, listing, cleanup |
| `30-git.zsh` | git aliases |
| `40-node.zsh` | npm/node shortcuts (runtime do `mise` quản lý) |
| `50-docker.zsh` | docker và `docker compose` |
| `60-devops.zsh` | kubectl, terraform, helm, mise, go helpers |
| `70-python.zsh` | `uv` workflow |
| `90-macos.zsh` / `90-linux.zsh` | OS-specific aliases |

Prompt Powerlevel10k nằm ở `dot_p10k.zsh`.
Nó được tune để segment `kubecontext`, `terraform`, `aws` chỉ hiện khi relevant và phân biệt `prod/stage/dev` bằng màu.

## Thêm tool mới

```bash
# Thêm CLI tool (version-managed): thêm dòng vào [tools] trong dot_config/mise/config.toml
# argocd = "latest"
make sync

# Thêm brew package
# Sửa Brewfile.tmpl rồi:
make sync
```
