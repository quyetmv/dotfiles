# Bitwarden session unlock + local REST server (eliminates per-call Node.js startup)
# Bitwarden items: name="proxmox-<cluster>", username=URL, password=API_TOKEN
_BW_PORT=8087

bwu() {
  export BW_SESSION
  BW_SESSION="$(bw unlock --raw </dev/tty)" || { echo "bwu: failed (run 'bw login' first?)"; return 1; }

  BW_SESSION="$BW_SESSION" bw sync &>/dev/null

  pkill -f "bw serve" 2>/dev/null
  BW_SESSION="$BW_SESSION" bw serve --hostname localhost --port "$_BW_PORT" &>/dev/null &
  disown
  sleep 0.5
  echo "bitwarden: unlocked"
}

_bw_api() { curl -sf "http://localhost:${_BW_PORT}/$1"; }
_bw_api_post() { curl -sf -X POST "http://localhost:${_BW_PORT}/$1"; }

# Self-heals staleness: syncs the running bw serve daemon (throttled) instead of
# requiring a manual bwu/master-password every time the vault changes.
_BW_SYNC_TTL=300
_bw_ensure() {
  local bw_status
  bw_status="$(_bw_api status 2>/dev/null | jq -r '.data.template.status // empty')"
  [[ -z "$bw_status" ]] && { echo "bw serve: not running — run bwu"; return 1; }
  [[ "$bw_status" != "unlocked" ]] && { echo "bw serve: locked — run bwu"; return 1; }

  local stamp="/tmp/.bw_serve_synced_$UID" now last=0
  now=$(date +%s)
  [[ -f "$stamp" ]] && last=$(<"$stamp")
  (( now - last < _BW_SYNC_TTL )) && return 0

  _bw_api_post sync >/dev/null && echo "$now" > "$stamp"
}

pxlist() {
  _bw_ensure || return 1
  _bw_api "list/object/items?search=proxmox" \
    | jq -r '.data.data[].name | select(startswith("proxmox-"))' \
    | sed 's/^proxmox-//'
}

# bwuse <cluster-name> -> proxmox-<cluster-name>: PROXMOX_VE_URL / PROXMOX_VE_API_TOKEN / PROXMOX_CLUSTER
#                       -> gitlab-token (if present): GITLAB_TOKEN
bwuse() {
  local cluster="${1:?Usage: bwuse <cluster-name>}"
  _bw_ensure || return 1

  local item url token
  item="$(_bw_api "list/object/items?search=proxmox-$cluster" \
    | jq -r --arg n "proxmox-$cluster" '.data.data[] | select(.name == $n)')"
  [[ -n "$item" && "$item" != "null" ]] || { echo "bwuse: 'proxmox-$cluster' not found (run bwu?)"; return 1; }

  url="$(printf '%s' "$item" | jq -r '.login.username')"
  token="$(printf '%s' "$item" | jq -r '.login.password')"
  export PROXMOX_VE_URL="$url"
  export PROXMOX_VE_API_TOKEN="$token"
  export PROXMOX_CLUSTER="$cluster"
  echo "proxmox: $cluster → $PROXMOX_VE_URL"

  local gl_item gl_token
  gl_item="$(_bw_api "list/object/items?search=gitlab-token" \
    | jq -r '.data.data[] | select(.name == "gitlab-token")')"
  if [[ -n "$gl_item" && "$gl_item" != "null" ]]; then
    gl_token="$(printf '%s' "$gl_item" | jq -r '.login.password')"
    export GITLAB_TOKEN="$gl_token"
    echo "gitlab: token exported"
  else
    echo "bwuse: 'gitlab-token' not found, skipped"
  fi
}

# SSH key pair from Bitwarden secure note (name="ssh-<key-name>",
# custom fields "private_key" / "public_key")
bwsshkey() {
  local key_name="${1:-id_quyetmv}"
  local dest="$HOME/.ssh/keys/$key_name"
  _bw_ensure || return 1

  local item
  item="$(_bw_api "list/object/items?search=ssh-$key_name" \
    | jq -r --arg n "ssh-$key_name" '.data.data[] | select(.name == $n)')"
  [[ -n "$item" && "$item" != "null" ]] || { echo "bwsshkey: 'ssh-$key_name' not found (run bwu?)"; return 1; }

  local priv pub
  priv="$(printf '%s' "$item" | jq -r '.fields[]? | select(.name=="private_key") | .value')"
  pub="$(printf '%s' "$item" | jq -r '.fields[]? | select(.name=="public_key") | .value')"
  [[ -n "$priv" && "$priv" != "null" ]] || { echo "bwsshkey: 'private_key' field missing on ssh-$key_name"; return 1; }

  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$priv" > "$dest"
  chmod 600 "$dest"
  echo "ssh key: ssh-$key_name → $dest"

  if [[ -n "$pub" && "$pub" != "null" ]]; then
    printf '%s\n' "$pub" > "$dest.pub"
    chmod 644 "$dest.pub"
    echo "ssh pubkey: ssh-$key_name → $dest.pub"
  fi
}

# Chezmoi age decryption key from Bitwarden (item "chezmoi-age-key")
bwagekey() {
  local dest="${1:-$HOME/.config/chezmoi/chezmoi_private_key}"
  _bw_ensure || return 1

  local item
  item="$(_bw_api "list/object/items?search=chezmoi-age-key" \
    | jq -r '.data.data[] | select(.name == "chezmoi-age-key")' 2>/dev/null || true)"
  [[ -n "$item" && "$item" != "null" ]] || { echo "bwagekey: 'chezmoi-age-key' not found in Bitwarden (run bwu?)"; return 1; }

  local key
  key="$(printf '%s\n' "$item" | jq -r '(.login.password // "") + "\n" + (.notes // "") + "\n" + (([.fields[]?.value] // []) | join("\n"))' 2>/dev/null | grep -oE 'AGE-SECRET-KEY-1[0-9A-Z]+' | head -n1 || true)"
  [[ -n "$key" ]] || { echo "bwagekey: no AGE-SECRET-KEY-1 found in chezmoi-age-key item"; return 1; }

  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$key" > "$dest"
  chmod 600 "$dest"
  echo "age key: chezmoi-age-key → $dest"
}

# GPG key import from Bitwarden (item "GPG - <key-id>", e.g. "GPG - 4EB1EAD1D65D87F3")
bwgpgkey() {
  local key_id="${1:-4EB1EAD1D65D87F3}"
  _bw_ensure || return 1

  local item
  item="$(_bw_api "list/object/items?search=GPG+-+$key_id" \
    | jq -r --arg n "GPG - $key_id" '.data.data[] | select(.name == $n)' 2>/dev/null || true)"
  if [[ -z "$item" || "$item" == "null" ]]; then
    item="$(_bw_api "list/object/items?search=$key_id" \
      | jq -r --arg id "$key_id" '.data.data[] | select(.name | contains($id))' 2>/dev/null || true)"
  fi
  [[ -n "$item" && "$item" != "null" ]] || { echo "bwgpgkey: 'GPG - $key_id' not found in Bitwarden (run bwu?)"; return 1; }

  local priv pub
  priv="$(printf '%s' "$item" | jq -r '.fields[]? | select(.name | contains("SECRET")) | .value' 2>/dev/null || true)"
  pub="$(printf '%s' "$item" | jq -r '.fields[]? | select(.name | contains("PUBLIC")) | .value' 2>/dev/null || true)"
  [[ -n "$priv" && "$priv" != "null" ]] || { echo "bwgpgkey: secret key field missing on item"; return 1; }

  _awk_format_pgp() {
    awk '{
      for (i = 1; i <= NF; i++) {
        if ($i == "-----BEGIN") {
          hdr = $i; while (i <= NF && substr($i, length($i)-4) != "-----") { i++; hdr = hdr " " $i; }
          print hdr "\n";
        } else if ($i == "-----END") {
          ftr = $i; while (i <= NF && substr($i, length($i)-4) != "-----") { i++; ftr = ftr " " $i; }
          print ftr;
        } else {
          print $i;
        }
      }
    }' <<< "$1"
  }

  # Import public key if present
  if [[ -n "$pub" && "$pub" != "null" ]]; then
    _awk_format_pgp "$pub" | gpg --batch --import >/dev/null 2>&1 || true
  fi

  # Import secret key
  if _awk_format_pgp "$priv" | gpg --batch --import; then
    local fpr
    fpr="$(gpg --list-secret-keys --with-colons "$key_id" 2>/dev/null | grep "^fpr" | head -n1 | cut -d: -f10 || true)"
    if [[ -n "$fpr" ]]; then
      (echo "${fpr}:6:") | gpg --import-ownertrust >/dev/null 2>&1 || true
    fi
    echo "gpg key: GPG - $key_id imported and trusted successfully"
  else
    echo "bwgpgkey: failed to import secret key"
    return 1
  fi
}

# SSH bastions (chezmoi-managed, age-encrypted at
# private_dot_ssh/private_conf.d/encrypted_bastions.age -> ~/.ssh/conf.d/bastions)
bastion-list() {
  grep -E '^Host ' "$HOME/.ssh/conf.d/bastions" 2>/dev/null
}

bastion-add() {
  local name="${1:?Usage: bastion-add <name> <range> <bastion-host>}"
  local range="${2:?Usage: bastion-add <name> <range> <bastion-host>}"
  local bastion="${3:?Usage: bastion-add <name> <range> <bastion-host>}"
  local dest="$HOME/.ssh/conf.d/bastions"

  {
    echo ""
    echo "Host $range"
    echo "    ProxyJump $bastion"
    echo "    StrictHostKeyChecking no"
    echo "    UserKnownHostsFile /dev/null"
    if [[ "$range" != *'*'* ]]; then
      echo ""
      echo "Host jump-$name"
      echo "    HostName $range"
      echo "    ProxyJump $bastion"
      echo "    StrictHostKeyChecking no"
      echo "    UserKnownHostsFile /dev/null"
    fi
  } >> "$dest"

  chezmoi re-add "$dest"
  echo "bastion: $name added, re-encrypted into source. Next:"
  echo "  cd \$(chezmoi source-path) && git add private_dot_ssh/private_conf.d/encrypted_bastions.age && git commit && git push"
}

# Kubernetes
alias k="kubectl"
alias kgp="kubectl get pods"
alias kgs="kubectl get svc"
alias kgd="kubectl get deploy"
alias kctx="kubectx"
alias kns="kubens"

# Infrastructure
alias tf="terraform"
alias tg="terragrunt"
alias h="helm"

# Terraform/Terragrunt shared plugin & source cache (dir created by run_onchange_after_directories.sh)
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
export TG_DOWNLOAD_DIR="$HOME/.terragrunt-cache"

# Remove stray .terragrunt-cache dirs under cwd
tgclean() {
  find . -type d -name ".terragrunt-cache" -prune -exec rm -rf {} +
}

# Runtime/tooling management
alias mk="mise"
alias mki="mise install"
alias mks="mise status"
alias mku="mise use"
alias mkug="mise use --global"
alias mkl="mise list"
alias mkla="mise list --all"

# Go Runtime Info
alias gov="go version"

# Calico (GitOps policy repo: review/apply diff between master and a branch)
alias caf="calicoctl apply -f"
alias cdf="calicoctl delete -f"

calico-review() {
    local branch_name="${1}"

    if [ -z "$branch_name" ]; then
        echo "❌ Usage: calico-review <branch-name>"
        echo "   Example: calico-review trieulv"
        echo "   Example: calico-review origin/trieulv"
        return 1
    fi

    local compare_branch="$branch_name"
    if [[ ! "$branch_name" =~ ^origin/ ]]; then
        compare_branch="origin/$branch_name"
    fi

    echo "Fetching from remote..."
    git fetch origin
    echo ""

    local deleted=$(git diff --name-only --diff-filter=D master...$compare_branch)
    local modified=$(git diff --name-only --diff-filter=AM master...$compare_branch)

    echo "=== DELETED files ==="
    if [ -n "$deleted" ]; then
        echo "$deleted"
        echo ""
        echo "Commands:"
        echo "$deleted" | while read f; do echo "  cdf $f"; done
    else
        echo "None"
    fi

    echo ""
    echo "=== ADDED/MODIFIED files ==="
    if [ -n "$modified" ]; then
        echo "$modified"
        echo ""
        echo "Commands (after merge):"
        echo "$modified" | while read f; do echo "  caf $f"; done
    else
        echo "None"
    fi
}

calico-sync() {
    local branch_name="${1}"

    if [ -z "$branch_name" ]; then
        echo "❌ Usage: calico-sync <branch-name>"
        echo "   Example: calico-sync trieulv"
        return 1
    fi

    local compare_branch="$branch_name"
    if [[ ! "$branch_name" =~ ^origin/ ]]; then
        compare_branch="origin/$branch_name"
    fi

    echo "════════════════════════════════════════════════════════"
    echo "  CALICO SYNC: $compare_branch → master"
    echo "════════════════════════════════════════════════════════"
    echo ""

    local current=$(git branch --show-current)
    if [ "$current" != "master" ]; then
        echo "⚠️  Currently on branch: $current"
        echo "📍 Checking out master..."
        git checkout master || { echo "❌ ERROR: Failed to checkout master"; return 1; }
        echo ""
    fi

    echo "📥 Pulling latest master..."
    git pull origin master || { echo "❌ ERROR: Failed to pull master"; return 1; }
    echo ""

    echo "📡 Fetching remote branches..."
    git fetch origin
    echo ""

    local deleted=$(git diff --name-only --diff-filter=D  master...$compare_branch)
    local modified=$(git diff --name-only --diff-filter=AM master...$compare_branch)

    local renamed_raw=$(git diff --name-status --diff-filter=R master...$compare_branch)
    local renamed_old=""
    local renamed_new=""
    if [ -n "$renamed_raw" ]; then
        renamed_old=$(echo "$renamed_raw" | awk '{print $2}')
        renamed_new=$(echo "$renamed_raw" | awk '{print $3}')
    fi

    _count_lines() { [ -z "$1" ] && echo 0 || echo "$1" | sed '/^\s*$/d' | wc -l | tr -d ' '; }

    local deleted_count=$(  _count_lines "$deleted")
    local modified_count=$( _count_lines "$modified")
    local renamed_count=$(  _count_lines "$renamed_old")

    local total_delete=$(( deleted_count + renamed_count ))
    local total_apply=$(( modified_count + renamed_count ))

    echo "📊 SUMMARY"
    echo "   Branch to merge : $compare_branch"
    echo "   Files deleted   : $deleted_count"
    echo "   Files renamed   : $renamed_count  (delete old + apply new)"
    echo "   Files modified  : $modified_count"
    echo "   ─────────────────────────────"
    echo "   Total to delete : $total_delete"
    echo "   Total to apply  : $total_apply"
    echo ""

    if [ -n "$deleted" ]; then
        echo "🗑️  DELETED ($deleted_count):"
        echo "$deleted" | grep -v '^\s*$' | nl -w2 -s'. '
        echo ""
    fi

    if [ -n "$renamed_old" ]; then
        echo "🔄 RENAMED ($renamed_count):"
        local i=1
        paste <(echo "$renamed_old") <(echo "$renamed_new") | while IFS=$'\t' read -r old new; do
            [ -n "$old" ] && printf "  %2d. %s\n      → %s\n" "$i" "$old" "$new"
            i=$(( i + 1 ))
        done
        echo ""
    fi

    if [ -n "$modified" ]; then
        echo "✏️  MODIFIED/ADDED ($modified_count):"
        echo "$modified" | grep -v '^\s*$' | nl -w2 -s'. '
        echo ""
    fi

    if [ $total_delete -eq 0 ] && [ $total_apply -eq 0 ]; then
        echo "ℹ️  No changes detected between master and $compare_branch"
        return 0
    fi

    echo "────────────────────────────────────────────────────────"
    read "response?🚀 Proceed with merge? (y/n) "
    echo ""

    [[ ! "$response" =~ ^[Yy]$ ]] && { echo "❌ Cancelled by user"; return 0; }

    echo "════════════════════════════════════════════════════════"
    echo "  STEP 1/4: Deleting ($total_delete file(s))"
    echo "════════════════════════════════════════════════════════"

    if [ $total_delete -eq 0 ]; then
        echo "  ⏭  No files to delete - SKIPPED"
    else
        local idx=1

        if [ -n "$renamed_old" ]; then
            echo "$renamed_old" | grep -v '^\s*$' | while read -r f; do
                echo "[$idx/$total_delete] 🔄 Delete renamed old: $f"
                cdf "$f"
                echo ""
                idx=$(( idx + 1 ))
            done
        fi

        if [ -n "$deleted" ]; then
            echo "$deleted" | grep -v '^\s*$' | while read -r f; do
                echo "[$idx/$total_delete] 🗑️  Delete: $f"
                cdf "$f"
                echo ""
                idx=$(( idx + 1 ))
            done
        fi
    fi
    echo ""

    echo "════════════════════════════════════════════════════════"
    echo "  STEP 2/4: Merging branch"
    echo "════════════════════════════════════════════════════════"
    echo "Command: git merge --no-ff $compare_branch"
    echo ""
    git merge --no-ff $compare_branch -m "Merge $compare_branch into master"
    if [ $? -ne 0 ]; then
        echo ""
        echo "❌ ERROR: Merge failed! Please resolve conflicts and try again."
        return 1
    fi
    echo ""
    echo "✅ Merge successful"
    echo ""

    echo "════════════════════════════════════════════════════════"
    echo "  STEP 3/4: Pushing to remote"
    echo "════════════════════════════════════════════════════════"
    echo "Command: git push origin master"
    echo ""
    git push origin master
    if [ $? -ne 0 ]; then
        echo ""
        echo "❌ ERROR: Push failed!"
        return 1
    fi
    echo ""
    echo "✅ Pushed to remote successfully"
    echo ""

    echo "════════════════════════════════════════════════════════"
    echo "  STEP 4/4: Applying ($total_apply file(s))"
    echo "════════════════════════════════════════════════════════"

    if [ $total_apply -eq 0 ]; then
        echo "  ⏭  No files to apply - SKIPPED"
    else
        local idx=1

        if [ -n "$renamed_new" ]; then
            echo "$renamed_new" | grep -v '^\s*$' | while read -r f; do
                echo "[$idx/$total_apply] 🔄 Apply renamed new: $f"
                caf "$f"
                echo ""
                idx=$(( idx + 1 ))
            done
        fi

        if [ -n "$modified" ]; then
            echo "$modified" | grep -v '^\s*$' | while read -r f; do
                echo "[$idx/$total_apply] ✏️  Apply: $f"
                caf "$f"
                echo ""
                idx=$(( idx + 1 ))
            done
        fi
    fi

    echo "════════════════════════════════════════════════════════"
    echo "  ✅ COMPLETED SUCCESSFULLY"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "Summary:"
    echo "  ✓ Deleted  : $deleted_count file(s)"
    echo "  ✓ Renamed  : $renamed_count file(s)  (old deleted + new applied)"
    echo "  ✓ Applied  : $modified_count file(s)"
    echo "  ✓ Merged   : $compare_branch → master"
    echo "  ✓ Pushed   : master → origin/master"
    echo ""
    echo "🎯 Next: Check GitLab UI - MR should show as 'Merged'"
    echo ""
}
