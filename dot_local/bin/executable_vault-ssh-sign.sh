#!/usr/bin/env bash
set -eo pipefail

export VAULT_ADDR="https://vault.giaohangtietkiem.vn"

if [ -z "${VAULT_TOKEN:-}" ]; then
    if [ -f "$HOME/.vault-token" ]; then
        VAULT_TOKEN=$(cat "$HOME/.vault-token")
        export VAULT_TOKEN
    else
        read -rsp "Nhập Vault Token của bạn: " VAULT_TOKEN
        export VAULT_TOKEN
        echo ""
    fi
fi

# ==============================================================================
# 1. DÙNG LẠI SSH-AGENT CÓ SẴN (KHÔNG TẠO MỚI, KHÔNG GHI ĐÈ FILE CỦA DOTFILES)
# ==============================================================================
agent_ok() {
    local rc=0
    ssh-add -l >/dev/null 2>&1 || rc=$?
    [ "$rc" -ne 2 ]
}

if ! agent_ok; then
    for f in "$HOME/.ssh/agent-environment" "$HOME/.ssh/agent-env"; do
        [ -f "$f" ] || continue
        # shellcheck disable=SC1090
        . "$f" >/dev/null 2>&1 || true
        agent_ok && break
    done
fi

if ! agent_ok; then
    VAULT_AGENT_ENV="$HOME/.ssh/agent-vault-env"
    if [ -f "$VAULT_AGENT_ENV" ]; then
        # shellcheck disable=SC1090
        . "$VAULT_AGENT_ENV" >/dev/null 2>&1 || true
    fi
    if ! agent_ok; then
        mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
        ssh-agent -s | sed 's/^echo/#echo/' > "$VAULT_AGENT_ENV"
        chmod 600 "$VAULT_AGENT_ENV"
        # shellcheck disable=SC1090
        . "$VAULT_AGENT_ENV" >/dev/null
    fi
    echo "ℹ️  Dùng agent riêng của script. Để shell hiện tại dùng được key: source $VAULT_AGENT_ENV"
fi

# ==============================================================================
# 2. THƯ MỤC TẠM AN TOÀN (ISOLATED CHO TỪNG USER / LẦN CHẠY)
# ==============================================================================
TMP_DIR=$(mktemp -d -t vault-ssh.XXXXXXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

KEY_FILE="$TMP_DIR/id_rsa_temp"
KEY_COMMENT="vault-temp-key-${USER}"

# ==============================================================================
# 3. XOÁ KEY + CERT VAULT CŨ CỦA CHÍNH USER NÀY KHỎI AGENT
# ==============================================================================
ssh-add -L 2>/dev/null | grep -F " ${KEY_COMMENT}" | while read -r line; do
    printf '%s\n' "$line" > "$TMP_DIR/old.pub"
    ssh-add -d "$TMP_DIR/old.pub" >/dev/null 2>&1 || true
done || true

# ==============================================================================
# 4. TẠO KEY MỚI VÀ XIN KÝ CHỨNG CHỈ TỪ VAULT
# ==============================================================================
ssh-keygen -t rsa -b 2048 -f "$KEY_FILE" -N "" -q -C "$KEY_COMMENT"

echo "⏳ Đang gửi public key lên HashiCorp Vault để ký certificate..."
vault write -field=signed_key ssh-client-signer/sign/ansible-devops-role \
    public_key=@"${KEY_FILE}.pub" \
    valid_principals="jms_admin" \
    key_id="${USER}" \
    ttl=12h > "${KEY_FILE}-cert.pub"

# ==============================================================================
# 5. THÊM KEY & CERT VÀO AGENT (12H)
# ==============================================================================
ssh-add -t 12h "$KEY_FILE"

echo "✅ Cấp chứng chỉ thành công!"
echo "👤 Audit Identity: ${USER}"
echo "🔑 SSH Agent Socket: ${SSH_AUTH_SOCK}"
