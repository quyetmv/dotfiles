# DevOps & Developer Dotfiles

[English version](README.md)

Bộ cấu hình môi trường chuyên nghiệp dành cho **DevOps Engineer** và **Developer**, hỗ trợ đa nền tảng (**macOS** và **Linux/WSL**) được quản lý tập trung bằng [chezmoi](https://chezmoi.io), [Homebrew](https://brew.sh/), và [mise](https://mise.jdx.dev/).

## Quick Setup

### macOS

```bash
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply quyetmv/dotfiles
```

### Linux / WSL

```bash
sudo apt update && sudo apt install -y curl git
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

Nếu bạn đang sửa repo này và muốn apply đúng nội dung checkout hiện tại:

```bash
git clone git@github.com:quyetmv/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
make install
```

`make install` dùng [scripts/bootstrap.sh](/Users/quyetmv/workspace/dotfiles/scripts/bootstrap.sh#L1) để apply chính repo hiện tại. Nếu muốn bootstrap từ remote published repo thay vì checkout local, đặt `CHEZMOI_REPO=user/repo`.

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

Bộ dotfiles này tích hợp các công cụ CLI hiện đại nhất để tối ưu hóa hiệu suất làm việc:

### [Starship Prompt](https://starship.rs/) 🌟
- **Features:**
  - Prompt siêu nhanh, hiển thị ngữ cảnh DevOps (K8s namespace, AWS profile, Terraform workspace) một cách thông minh.
  - Tích hợp cảnh báo thời gian thực khi chạy lệnh lâu (`cmd_duration`).
  - Tùy biến cao, hiển thị icon chuẩn Nerd Fonts.

### [Atuin](https://atuin.sh/) 🕰️
- **Features:**
  - Thay thế trình tìm kiếm history mặc định bằng SQLite database.
  - Tìm kiếm history theo session hoặc global, giao diện TUI trực quan.
  - Tìm lại các lệnh Cloud/K8s phức tạp cực nhanh với giao diện thân thiện.

### [Zoxide](https://github.com/ajeetdsouza/zoxide) 🏎️
- **Features:**
  - Một lệnh `cd` thông minh hơn, tự học thói quen di chuyển thư mục của bạn.
  - Hỗ trợ nhảy nhanh qua các thư mục thường xuyên truy cập (`z <name_fragment>`).

### [Eza](https://eza.rocks/) 📁
- **Features:**
  - Bản nâng cấp của `ls` với icons, màu sắc và metadata trực quan hơn.
  - Tích hợp trạng thái Git ngay trên danh sách file/thư mục.
  - Aliases mặc định: `ls`, `ll`, `la`, `lt` (tree view).

### [Fastfetch](https://github.com/fastfetch-cli/fastfetch) ⚡
- **Features:**
  - Hiển thị thông tin hệ thống (OS, Kernel, CPU, RAM...) đẹp mắt và nhanh chóng.
  - Thay thế hiện đại cho `neofetch`.

### [Mise-en-place](https://mise.jdx.dev/) 🔧
- **Features:**
  - Quản lý version các runtime (Python, Go, Node) và DevOps tools (Kubectl, Terraform, Helm).
  - Tự động active tool versions khi vào thư mục project qua `.tool-versions`.

### [Lazygit](https://github.com/jesseduffield/lazygit) 🦥
- **Features:**
  - TUI thần thánh dành cho Git. Xem log, stage file, giải quyết conflict chỉ với vài phím tắt.
  - Tích hợp `delta` để hiển thị diff đẹp mắt và màu sắc.

### [K9s](https://k9scli.io/) ☸️
- **Features:**
  - Terminal UI mạnh mẽ nhất để quản lý Kubernetes clusters.
  - Theo dõi Pods, Logs, Events theo thời gian thực mà không cần gõ lệnh dài.

### [fzf](https://github.com/junegunn/fzf) & [Ripgrep](https://github.com/BurntSushi/ripgrep) 🔎 heroes
- **Features:**
  - Tìm kiếm mờ (fuzzy find) file, thư mục và history cực nhanh.
  - Tìm kiếm nội dung file với tốc độ sấm sét bằng `rg`.
  - Tích hợp preview nội dung bằng `bat`.

---

## AI Agent Integration 🤖

Dự án này được tối ưu hóa để làm việc cùng các AI Coding Agents. Hệ thống áp dụng triết lý **High-Standard Engineering**: AI cần thẳng thắn, thách thức các giả định sai lầm, ưu tiên sự chính xác và luôn cực kỳ ngắn gọn.

### AI Model Instructions

- **Claude (Claude Code/iTerm)**: Tuân thủ các chỉ dẫn trong `CLAUDE.md`. Chế độ "High-Standard" được bật mặc định.
- **Gemini (Desktop/IDE)**: Áp dụng các quy tắc về độ chính xác cao và nghiên cứu kỹ chi tiết kỹ thuật trước khi đề xuất.
- **Codex / OpenAI**: Ưu tiên các giải pháp thực dụng (pragmatic), code sạch và có thể chạy ngay lập tức.

### Modular AI Skills 🧠

Chúng tôi xây dựng hệ thống tri thức dạng module tại `dot_agents/skills/` để AI có thể "đọc và hiểu" sâu về stack công nghệ của bạn. Các kỹ năng hiện có:
- **`uv`**: Quy chuẩn quản lý Python hiện đại.
- **`kubernetes`**: Best practices về resource management, Kustomize và Helm.

---

## Dependency ownership

| Manifest | Quản lý |
|----------|---------|
| `Brewfile.tmpl` | Homebrew formulas, casks, Mac App Store |
| `dot_tool-versions` | Version-pinned runtimes and DevOps CLI tools via mise |
| `dot_config/mise/config.toml` | mise settings only, không khai báo tool versions |
| `dot_gitconfig.tmpl` + `dot_gitconfig-personal.tmpl` + `dot_gitconfig-work.tmpl` | Git common config + personal/work identities |
| `dot_p10k.zsh` | Powerlevel10k prompt config lấy cảm hứng từ repo tham chiếu |
| `dot_zsh.d/*` | Ordered shell modules theo nhóm: env, navigation, git, node, docker, devops, python |
| `pyproject.toml` + `uv.lock` | Python deps (per project) |

## Cấu hình đặc thù cho từng máy (Machine-specific config)

Trong quá trình làm việc, bạn sẽ có những biến môi trường nhạy cảm (API Keys, Tokens) hoặc các thiết lập dùng riêng cho máy hiện tại mà không muốn lưu lên GitHub.

Dotfiles này đã cấu hình **bỏ qua (ignore)** file `~/.private` khỏi Git. Bạn có thể sử dụng file này để lưu trữ an toàn các bí mật cá nhân cá nhân và công việc.

**Cách sử dụng:**

1. Tạo file trên máy của bạn (chỉ làm 1 lần):
   ```bash
   touch ~/.private
   ```
2. Thêm nội dung của bạn vào file (dùng nano, vim, hoặc VSCode):
   ```bash
   # Ví dụ trong ~/.private
   export WORK_API_KEY="secret123"
   export AWS_PROFILE="production"
   alias company="cd ~/workspace/company"
   ```
3. Zsh sẽ tự động nạp (`source`) file này mỗi khi bạn mở Terminal. Để áp dụng ngay lập tức, chạy:
   ```bash
   source ~/.private
   ```

Git work identity có thể bật bằng env vars khi apply:

```bash
CHEZMOI_WORK_GIT_DIR="~/workspace/company/" \
CHEZMOI_WORK_GIT_NAME="Your Work Name" \
CHEZMOI_WORK_GIT_EMAIL="you@company.com" \
CHEZMOI_WORK_GITHUB_USER="company-gh-user" \
chezmoi apply --source="$PWD" --force
```

## Runtime management

Node, Go, Python và các DevOps CLIs đều được quản lý qua `mise`.

Sau khi sync/apply:

```bash
exec zsh -l
mise install
node --version
go version
uv --version
```

Đổi version mặc định toàn máy:

```bash
mise use --global node@22
mise use --global go@1.24
```

Pin version cho từng project:

```bash
mise use node@22
mise use go@1.24
```

`mise` cũng hỗ trợ đọc các file version quen thuộc như `.nvmrc`, `.node-version`, `.go-version`.

## Python and uv

Repo này chỉ cài `python` và `uv` binary qua `mise`. Nó không tự tạo virtualenv global.

Sau khi sync/apply:

```bash
exec zsh -l
command -v uv
uv --version
```

Trong từng project Python:

```bash
uv venv
uv lock
uv sync
uv run python ...
```

Repo cũng quản lý sẵn một workspace Python dùng chung cho tooling DevOps ở `~/.devops-env`:

```bash
make devops-env
```

Hoặc chạy tay:

```bash
cd ~/.devops-env
uv sync
```

Thư mục `bin` của venv đã nằm trong `PATH`, và `make devops-env` bật auto-activate cho các zsh shell mới. Khi cần vào env rõ ràng, chạy `devenv-activate`. Nếu muốn tắt auto-activate, chạy `devenv-auto-off`.

## Validation

```bash
make test               # repo-side checks
make validate           # post-apply checks
```

## Reference clones

Thư mục `dotfiles/` trong root chỉ nên dùng làm repo tham chiếu tạm thời. Nó đã được ignore bởi git và `chezmoi`, nên sẽ không bị apply vào `$HOME`.

## Shell structure

`~/.zsh.d` được load theo thứ tự tên file, nên repo dùng numeric prefixes để dễ quản lý:

- `10-env.zsh`: env chung
- `20-navigation.zsh`: navigation và file utilities
- `30-git.zsh`: git aliases
- `40-node.zsh`: node/npm shortcuts
- `50-docker.zsh`: docker / docker compose
- `60-devops.zsh`: kubectl / terraform / helm / mise
- `70-python.zsh`: `uv` workflow
- `80-modern-tools.zsh`: Starship, Atuin, Zoxide, Eza initialization
- `90-macos.zsh` / `90-linux.zsh`: OS-specific additions

Prompt theme được cấu hình riêng ở `~/.p10k.zsh`.
Prompt này được tune cho DevOps workflow: chỉ hiện `k8s`, `tf`, `aws` khi command hiện tại có liên quan, và đổi màu rõ hơn cho `prod/stage/dev`.

## Commands

| Command | Purpose |
|---------|---------|
| `chezmoi managed` | List managed targets |
| `chezmoi diff` | Preview pending changes |
| `chezmoi apply` | Apply managed files |
| `chezmoi update` | Pull + apply |

## Acknowledgements

This project is inspired by and based on [Helder Burato Berto's dotfiles](https://github.com/helderberto/dotfiles).
