# Bitwarden session unlock + local REST server (eliminates per-call Node.js startup)
# Bitwarden items: name="proxmox-<cluster>", username=URL, password=API_TOKEN
_BW_PORT=8087

bwu() {
  export BW_SESSION
  BW_SESSION="$(bw unlock --raw </dev/tty)" || { echo "bwu: failed (run 'bw login' first?)"; return 1; }

  pkill -f "bw serve" 2>/dev/null
  BW_SESSION="$BW_SESSION" bw serve --hostname localhost --port "$_BW_PORT" &>/dev/null &
  disown
  sleep 0.5
  echo "bitwarden: unlocked"
}

_bw_api() { curl -sf "http://localhost:${_BW_PORT}/$1"; }

pxuse() {
  local cluster="${1:?Usage: pxuse <cluster-name>}"

  local item url token
  item="$(_bw_api "list/object/items?search=proxmox-$cluster" \
    | jq -r --arg n "proxmox-$cluster" '.data.data[] | select(.name == $n)')"
  [[ -n "$item" && "$item" != "null" ]] || { echo "pxuse: 'proxmox-$cluster' not found (run bwu?)"; return 1; }

  url="$(printf '%s' "$item" | jq -r '.login.username')"
  token="$(printf '%s' "$item" | jq -r '.login.password')"

  export PROXMOX_VE_URL="$url"
  export PROXMOX_VE_API_TOKEN="$token"
  export PROXMOX_CLUSTER="$cluster"
  echo "proxmox: $cluster → $PROXMOX_VE_URL"
}

pxlist() {
  _bw_api "list/object/items?search=proxmox" \
    | jq -r '.data.data[].name | select(startswith("proxmox-"))' \
    | sed 's/^proxmox-//'
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
