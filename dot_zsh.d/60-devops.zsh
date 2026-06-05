# Bitwarden session unlock
# Bitwarden items: name="proxmox-<cluster>", username=URL, password=API_TOKEN
bwu() {
  export BW_SESSION
  BW_SESSION="$(bw unlock --raw </dev/tty)" || { echo "bwu: failed (run 'bw login' first?)"; return 1; }
  echo "bitwarden: unlocked"
}

# Proxmox cluster context switcher (pulls from Bitwarden)
pxuse() {
  local cluster="${1:?Usage: pxuse <cluster-name>}"
  [[ -n "${BW_SESSION:-}" ]] || { echo "pxuse: run 'bwu' first"; return 1; }

  local item url token
  item="$(bw get item "proxmox-$cluster" --session "$BW_SESSION" 2>/dev/null)"
  [[ -n "$item" ]] || { echo "pxuse: 'proxmox-$cluster' not found in Bitwarden"; return 1; }

  url="$(printf '%s' "$item" | jq -r '.login.username')"
  token="$(printf '%s' "$item" | jq -r '.login.password')"

  export PROXMOX_VE_URL="$url"
  export PROXMOX_VE_API_TOKEN="$token"
  export PROXMOX_CLUSTER="$cluster"
  echo "proxmox: $cluster → $PROXMOX_VE_URL"
}

pxlist() {
  [[ -n "${BW_SESSION:-}" ]] || { echo "pxlist: run 'bwu' first"; return 1; }
  bw list items --search proxmox --session "$BW_SESSION" 2>/dev/null \
    | grep -o '"name":"proxmox-[^"]*"' \
    | sed 's/"name":"proxmox-//;s/"//'
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
