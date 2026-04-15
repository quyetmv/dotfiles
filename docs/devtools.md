# DevOps Tools & Runtimes

Chi tiết về các tool được quản lý trong dotfiles.

## Ownership

- `dot_tool-versions`: source of truth cho versions của runtimes và DevOps CLIs
- `dot_config/mise/config.toml`: chỉ chứa `mise` settings toàn cục
- `Brewfile.tmpl`: source of truth cho Homebrew formulas, casks, và `mas`
- `dot_p10k.zsh`: Powerlevel10k prompt config lấy cảm hứng từ repo tham chiếu
- `dot_zsh.d/*`: shell modules được load theo thứ tự tên file

## mise (`dot_tool-versions`)

`mise` quản lý tất cả CLI tools có version, cài đặt tự động khi chạy `mise install`.

### Languages & Package Managers
| Tool | Version | Mô tả |
|------|---------|-------|
| node | 22 | Node.js runtime |
| python | 3.12 | Python runtime |
| go | 1.24 | Go runtime |
| uv | latest | Python package manager (thay pip) |

### Infrastructure & Cloud
| Tool | Version | Mô tả |
|------|---------|-------|
| terraform | 1.11 | Infrastructure as Code |
| terraform-docs | 0.20 | Terraform docs generator |
| terragrunt | 0.77 | Terraform wrapper |
| kubectl | 1.32 | Kubernetes CLI |
| helm | 3.17 | Kubernetes package manager |
| kustomize | 5.6 | Kubernetes config customization |
| awscli | 2 | AWS command-line |
| sops | 3.10 | Secrets encryption |
| age | 1.2 | File encryption |
| vault | latest | HashiCorp secrets management |

### Kubernetes Tools
| Tool | Version | Mô tả |
|------|---------|-------|
| k9s | latest | Kubernetes TUI dashboard |
| kubectx | latest | Switch K8s contexts |
| kubens | latest | Switch K8s namespaces |
| kubecm | latest | Kubeconfig manager |

### CLI Utilities
| Tool | Version | Mô tả |
|------|---------|-------|
| jq | 1.7 | JSON processor |
| yq | 4.45 | YAML processor |
| shellcheck | 0.10 | Shell script linter |
| shfmt | 3.11 | Shell script formatter |
| yamllint | 1.37 | YAML linter |
| pre-commit | 4.2 | Git hook framework |
| infracost | latest | Cloud cost estimation |
| lazydocker | latest | Docker TUI |

## Homebrew (`Brewfile.tmpl`)

### Cross-platform (macOS + Linuxbrew)
Shell tools: `bat`, `fd`, `fzf`, `ripgrep`, `lsd`, `lazygit`, `neovim`, `tmux`, `mise`, `chezmoi`, `powerlevel10k`, `z`, zsh plugins, `mysql-client`, `redis` (`redis-cli`).

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
# Thêm CLI tool (version-managed)
echo "argocd latest" >> dot_tool-versions
make sync

# Thêm brew package
# Sửa Brewfile.tmpl rồi:
make sync
```
