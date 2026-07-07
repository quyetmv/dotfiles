# Plans

## Sprint: dotfiles optimization (từ review 2026-07-03)

Nguồn: review session 2026-07-03. Quyết định user: giữ **zoxide**, bỏ `z`.

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1 | Brewfile cleanup: bỏ `mysql-client` trùng, bỏ `jq`/`bat`/`lazygit` (mise là owner theo dot_tool-versions), bỏ `z` (giữ zoxide) [skip:tdd config-only] | `make test` pass; mỗi formula xuất hiện đúng 1 lần; `z` không còn trong Brewfile | - | cc:完了 [83d22cc] |
| 2 | zshrc: bỏ init `z.sh` (cả darwin/linux), bỏ mise shims khỏi PATH (giữ `mise activate` — .zshrc chỉ chạy interactive nên shims thừa) [skip:tdd config-only] | `make test` pass; zshrc chỉ còn 1 cơ chế mise; không còn reference z.sh | 1 | cc:完了 [6fca953] |
| 3 | zsh.d dedup: bỏ bindkey `\e[H`/`\e[F` thừa trong 80-modern-tools (zshrc đã bind sau); gom alias listing `l`/`ll`/`la`/`lla` về 80-modern-tools với eza + fallback ls [skip:tdd config-only] | `make test` pass; alias listing chỉ định nghĩa ở 1 file; không còn bindkey trùng | - | cc:完了 [1262912] |
| 4 | Git hygiene: untrack `.nvimlog` (runtime log), thêm vào .gitignore [skip:tdd config-only] | `.nvimlog` không còn trong `git ls-files`; đã có trong .gitignore | - | cc:完了 [499e28b] |
| 5 | Docs: README nói rõ p10k là prompt mặc định / Starship là opt-in (`DOTFILES_PROMPT=starship`); sync section Bitwarden sang README.vn.md [skip:tdd docs-only] | README không mô tả Starship như prompt chính; README.vn.md có section Secrets Management | 1,2,3 | cc:完了 [e23af76] |
| 6 | fix(pre-existing): test 7 dry-run fail — thêm `ssh_bastions = []` vào minimal config của scripts/test-chezmoi.sh (sync data contract, cùng pattern `work_configs = []`; thiếu từ khi thêm bastions f4e4954) | test 7 pass | - | cc:完了 [a0bd811] |
| 7 | fix(pre-existing): test 8 secrets scan false positive — nâng scanner từ keyword-presence lên literal-secret detection (quoted assignment, PRIVATE KEY block, token prefix glpat-/ghp_/sk-/AKIA/xox) cho cả nhánh rg lẫn grep; verify 2 chiều (clean pass + secret giả bị bắt) | test 8 pass; secret giả bị phát hiện khi test tay | - | cc:完了 [a0bd811] |

## Phase 2: Linux onboarding một-lệnh (2026-07-07)

Nguồn: session Ubuntu init fail (sshpass, prompt macOS, mất chezmoi PATH, age key abort).
Spec skip reason: repo không có spec.md convention; install contract ghi trong README (2.2), enforce bằng Docker e2e (2.3).

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 2.1 | Rework `scripts/bootstrap.sh` thành one-command cross-OS: cài chezmoi với `-b ~/.local/bin` (idempotent, PATH cho session); thiếu age key → warning rõ + tự `--exclude=encrypted`; Linux: sau init tự chạy `setup-linux.sh packages`; giữ CHEZMOI_REPO env override [tdd:skip:shell-bootstrap-docker-e2e] | Docker Ubuntu sạch chạy bootstrap.sh → "Setup validated" 0 ✗; chezmoi còn trên PATH sau khi xong (`~/.local/bin/chezmoi` tồn tại) | - | cc:完了 [f7f7bf3] |
| 2.2 | README EN/VN Linux section = 1 lệnh duy nhất (`curl -fsLS https://raw.githubusercontent.com/quyetmv/dotfiles/main/scripts/bootstrap.sh \| bash`); bảng env vars pre-seed cho init zero-question (CHEZMOI_GIT_EMAIL/NAME/GITHUB_USER, CI=1); giữ manual steps làm fallback [tdd:skip:docs-only] | Cả 2 README không còn one-liner thiếu `-b`; có bảng env vars; VN sync với EN | 2.1 | cc:完了 [2b3fe1d] |
| 2.3 | Thêm mode `--bootstrap` vào test-docker.sh: container Ubuntu sạch chạy đúng scripts/bootstrap.sh (bản local) end-to-end làm regression guard | `./scripts/test-docker.sh --bootstrap` exit 0, validate 0 ✗ | 2.1 | cc:完了 [f1482b4] |
| 2.4 | fix: bootstrap tự clone/pull source — chezmoi init reuse stale clone không pull nên máy có clone cũ cứ nhận template outdated [tdd:skip:covered-by-bootstrap-e2e] | Docker --bootstrap 0 ✗ | 2.1 | cc:完了 [2626742] |
