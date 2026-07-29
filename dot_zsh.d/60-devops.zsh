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

pxlist() {
  _bw_api "list/object/items?search=proxmox" \
    | jq -r '.data.data[].name | select(startswith("proxmox-"))' \
    | sed 's/^proxmox-//'
}

# bwuse <cluster-name> -> proxmox-<cluster-name>: PROXMOX_VE_URL / PROXMOX_VE_API_TOKEN / PROXMOX_CLUSTER
#                       -> gitlab-token (if present): GITLAB_TOKEN
bwuse() {
  local cluster="${1:?Usage: bwuse <cluster-name>}"

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
