# DevOps & Developer Dotfiles

[English version](README.md)

Bộ cấu hình môi trường chuyên nghiệp dành cho **DevOps Engineer** và **Developer**, hỗ trợ đa nền tảng (**macOS** và **Linux/WSL**) được quản lý tập trung bằng [chezmoi](https://chezmoi.io), [Homebrew](https://brew.sh/), và [mise](https://mise.jdx.dev/).

## Quick Setup

Một lệnh duy nhất cho cả 2 nền tảng — cài chezmoi vào `~/.local/bin`, cài system packages (Linux), tự phát hiện thiếu age key (bỏ qua secrets kèm cảnh báo rõ ràng thay vì chết giữa chừng), rồi apply tất cả:

```bash
curl -fsLS https://raw.githubusercontent.com/quyetmv/dotfiles/main/scripts/bootstrap.sh | bash

# rồi reload shell (đặt font terminal là MesloLGS NF)
exec zsh -l
```

Secrets: muốn có luôn `~/.secrets/.private`, restore age key vào `~/.config/chezmoi/chezmoi_private_key` (chmod 600, từ Bitwarden hoặc máy khác) **trước** khi chạy bootstrap — hoặc chạy lại `chezmoi apply` sau khi restore.

### Init không cần trả lời prompt (pre-seed)

| Env var | Tác dụng |
|---------|----------|
| `CI=1` | Bỏ qua TOÀN BỘ prompt (dùng default / env bên dưới) |
| `CHEZMOI_GIT_EMAIL` / `CHEZMOI_GIT_NAME` / `CHEZMOI_GITHUB_USER` | Git identity cá nhân |
| `CHEZMOI_WORK_GIT_DIR` / `CHEZMOI_WORK_GIT_EMAIL` / `CHEZMOI_WORK_GIT_NAME` | Git identity công việc (theo thư mục) |
| `CHEZMOI_ENABLE_SSH_KEYGEN=1` | Tạo SSH key nếu chưa có |
| `CHEZMOI_ENABLE_DOCK=1` | Tùy chỉnh Dock macOS |
| `CHEZMOI_ENABLE_PERSONAL_APPS=1` | Cask cá nhân macOS (EvKey/Telegram/Sublime Text) |
| `CHEZMOI_ENABLE_MAS_APPS=1` | App Mac App Store qua mas |

Các câu hỏi chỉ dành cho macOS (Dock, MAS, personal apps) không bao giờ hỏi trên Linux.

### Manual fallback

```bash
# macOS
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply quyetmv/dotfiles

# Linux / WSL — phải cài packages TRƯỚC khi apply, nếu không script
# run_onchange chsh/font bị skip 1 lần (chưa có zsh) và không bao giờ chạy lại
sudo apt update && sudo apt install -y curl git make
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init quyetmv/dotfiles
cd "$(~/.local/bin/chezmoi source-path)" && make linux
~/.local/bin/chezmoi apply
exec zsh -l
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
| Homebrew formulas (CLI tools) | ✅ | — (không Linuxbrew; xem apt/mise) |
| Casks (GUI apps) | ✅ | — |
| Personal macOS casks | Optional | — |
| Mac App Store apps (`mas`) | Optional | — |
| mise runtimes (kubectl, terraform, eza, zoxide, fastfetch, atuin...) | ✅ | ✅ |
| setup-linux.sh (apt, Docker) | — | ✅ |

📋 Full tool list: [docs/devtools.md](docs/devtools.md)

## Daily usage

```bash
chezmoi update           # pull + apply latest changes
chezmoi diff && chezmoi apply
make sync                # after editing Brewfile.tmpl or dot_config/mise/config.toml
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
| `dot_config/mise/config.toml` | mise settings + version-pinned runtimes và DevOps CLI tools (`[tools]`) |
| `dot_gitconfig.tmpl` + `dot_gitconfig-personal.tmpl` + `dot_gitconfig-work.tmpl` | Git common config + personal/work identities |
| `dot_p10k.zsh` | Powerlevel10k prompt config lấy cảm hứng từ repo tham chiếu |
| `dot_zsh.d/*` | Ordered shell modules theo nhóm: env, navigation, git, node, docker, devops, python |
| `pyproject.toml` + `uv.lock` | Python deps (per project) |
| `private_dot_secrets/encrypted_private_dot_private.age` | Secrets mã hoá bằng age, decrypt ra `~/.secrets/.private` |
| `private_dot_ssh/private_conf.d/encrypted_bastions.age` | SSH bastion ProxyJump config mã hoá bằng age, decrypt ra `~/.ssh/conf.d/bastions` |

## Cấu hình đặc thù cho từng máy (Machine-specific config)

`.zshrc` source theo thứ tự: `~/.secrets/.private`, rồi `~/.extra`, rồi `~/.functions`. Chọn đúng loại:

### `~/.secrets/.private` — secrets đã mã hoá (chezmoi + age)

Dùng cho thứ nhạy cảm (API key, token) nhưng vẫn muốn sync qua git giữa các máy của bạn. Được chezmoi quản lý, lưu **mã hoá bằng age** trong repo tại `private_dot_secrets/encrypted_private_dot_private.age`, apply ra `~/.secrets/.private` với mode `600`.

```bash
chezmoi edit ~/.secrets/.private   # decrypt, mở $EDITOR (nvim), re-encrypt khi save
chezmoi apply                      # ghi plaintext ra ~/.secrets/.private
source ~/.secrets/.private          # hoặc: exec zsh -l
```

Cần age identity key tại `~/.config/chezmoi/chezmoi_private_key` (public recipient đã khai trong `.chezmoi.toml.tmpl`). **Backup key này** (vd Bitwarden) — mất key thì file mã hoá không khôi phục được. Bootstrap sẽ bỏ qua secrets kèm cảnh báo nếu thiếu key; restore key rồi chạy lại `chezmoi apply`.

File mã hoá an toàn để commit/push (`git add private_dot_secrets/encrypted_private_dot_private.age`) — đó là cách nó sync sang máy khác.

### `~/.extra` / `~/.functions` — chỉ local, không track bởi git hay chezmoi

Dùng cho thứ hoàn toàn local, không cần sync hay mã hoá (`.chezmoiignore`'d). Tạo và sửa trực tiếp:

```bash
touch ~/.extra
echo 'alias company="cd ~/workspace/company"' >> ~/.extra
source ~/.extra
```

### `~/.ssh/conf.d/bastions` — SSH ProxyJump config (age-encrypted, git-tracked)

Cùng cơ chế với `~/.secrets/.private`: lưu mã hoá tại `private_dot_ssh/private_conf.d/encrypted_bastions.age`, decrypt ra `~/.ssh/conf.d/bastions`. Chọn cách này thay vì `[data]` prompt cũ để có git history và sync giữa các máy qua age key chung.

```bash
bastion-add <name> <range> <bastion-host>   # append 1 Host block, rồi `chezmoi re-add`
bastion-list                                # grep Host trong file đã apply
chezmoi edit ~/.ssh/conf.d/bastions          # hoặc sửa tự do trong $EDITOR

cd "$(chezmoi source-path)"
git add private_dot_ssh/private_conf.d/encrypted_bastions.age
git commit -m "..." && git push
```

`bastion-add`/`bastion-list` nằm trong `dot_zsh.d/60-devops.zsh`. Tự động bỏ qua block `jump-<name>` khi `range` chứa `*` (wildcard range không thể làm `HostName`).

## Sửa file do chezmoi quản lý & push ngược lại git

`chezmoi edit <target>` mở file **source**, nằm ngay trong git working tree này (`chezmoi source-path` == root repo). Với target đã mã hoá (vd `~/.secrets/.private`) nó decrypt ra buffer tạm rồi re-encrypt lại vào source tree khi save. Chezmoi không bao giờ tự commit — sửa xong thì commit như bình thường:

```bash
cd "$(chezmoi source-path)"
git status
git add <file>
git commit -m "..."
git push
```

File template không mã hoá (vd `dot_zshrc.tmpl`) cũng có thể sửa trực tiếp trong repo bằng editor bất kỳ — `chezmoi edit` chỉ cần thiết khi muốn xem bản *đã decrypt* của target mã hoá.

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
- `60-devops.zsh`: kubectl / terraform / helm / mise / calico (calicoctl, vendored tại `bin/calicoctl`)
- `70-python.zsh`: `uv` workflow
- `80-modern-tools.zsh`: Starship, Atuin, Zoxide, Eza initialization
- `90-macos.zsh` / `90-linux.zsh`: OS-specific additions

Prompt theme được cấu hình riêng ở `~/.p10k.zsh`.
Prompt này được tune cho DevOps workflow: chỉ hiện `k8s`, `tf`, `aws` khi command hiện tại có liên quan, và đổi màu rõ hơn cho `prod/stage/dev`.

## Secrets Management (Bitwarden CLI) 🔐

Credentials Proxmox lưu trong Bitwarden, fetch on-demand qua `dot_zsh.d/60-devops.zsh`. Item đặt tên theo convention `proxmox-<cluster>`, với `login.username` = API URL và `login.password` = API token.

### Setup

```bash
bw login    # login device 1 lần
bwu         # unlock vault + start REST server local trên localhost:8087
```

### Thêm vault item

```bash
bw get template item \
  | jq '.type=1 | .name="proxmox-<cluster>" | .notes="" | .login.username="<api-url>" | .login.password="<api-token>"' \
  | bw encode | bw create item

bwu   # bw serve cache vault lúc start, chạy lại để nhận item mới
```

### List & use

```bash
pxlist            # list các cluster proxmox-*
bwuse <cluster>   # export PROXMOX_VE_URL / PROXMOX_VE_API_TOKEN / PROXMOX_CLUSTER, kèm GITLAB_TOKEN nếu có
```

### GitLab token

1 item duy nhất, tên `gitlab-token`, chỉ dùng `login.password`. `bwuse <cluster>` tự nhận nó cùng lúc với credentials Proxmox:

```bash
bw get template item \
  | jq '.type=1 | .name="gitlab-token" | .notes="" | .login.password="<personal-access-token>"' \
  | bw encode | bw create item

bwu               # chạy lại để refresh bw serve
bwuse <cluster>   # export PROXMOX_* và GITLAB_TOKEN cùng lúc
```

### SSH key pair

Secure note, tên `ssh-<key-name>` (mặc định key name là `id_quyetmv`), key nằm trong custom field `private_key` / `public_key`. `bwsshkey` ghi ra `~/.ssh/keys/<key-name>` (mode `600`) và `~/.ssh/keys/<key-name>.pub` (mode `644`):

```bash
bw get template item \
  | jq --rawfile priv ~/.ssh/keys/id_quyetmv --rawfile pub ~/.ssh/keys/id_quyetmv.pub \
      '.type=2 | .secureNote.type=0 | .name="ssh-id_quyetmv"
       | .fields=[{name:"private_key",value:$priv,type:0},{name:"public_key",value:$pub,type:0}]' \
  | bw encode | bw create item

bwu                 # chạy lại để refresh bw serve
bwsshkey            # kéo "ssh-id_quyetmv" -> ~/.ssh/keys/id_quyetmv(.pub)
bwsshkey other_key  # hoặc item "ssh-<name>" bất kỳ -> ~/.ssh/keys/<name>(.pub)
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
