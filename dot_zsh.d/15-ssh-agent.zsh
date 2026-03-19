# SSH Agent configuration
# This ensures that ssh-agent is running and you only have to enter your
# SSH key passphrase once per session/reboot.

SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initializing new SSH agent..."
    # spawn ssh-agent
    ssh-agent -s | sed 's/^echo/#echo/' > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    
    # Try to add default keys
    if [[ -f "$HOME/.ssh/id_rsa" || -f "$HOME/.ssh/id_ed25519" ]]; then
        ssh-add
    fi
}

# Source SSH settings, if applicable
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    
    # Check if agent is actually running
    if ! kill -0 $SSH_AGENT_PID 2>/dev/null; then
        start_agent
    fi
else
    start_agent
fi
