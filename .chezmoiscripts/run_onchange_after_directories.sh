#!/usr/bin/env bash
# Create workspace directories

set -e

echo "📁 Creating workspace directories..."

# Create workspace directory
if [ ! -d "$HOME/workspace" ]; then
    mkdir -p "$HOME/workspace"
    echo "  ✓ Created ~/workspace"
else
    echo "  ✓ ~/workspace already exists"
fi

# Create standard workspace subdirectories
for subdir in personal labs; do
    if [ ! -d "$HOME/workspace/$subdir" ]; then
        mkdir -p "$HOME/workspace/$subdir"
        echo "  ✓ Created ~/workspace/$subdir"
    else
        echo "  ✓ ~/workspace/$subdir already exists"
    fi
done

echo "✓ Workspace directories ready"

# Private directory for credential files — restricted permissions
if [ ! -d "$HOME/.secrets" ]; then
    mkdir -p "$HOME/.secrets"
    chmod 700 "$HOME/.secrets"
    echo "  ✓ Created ~/.secrets (700)"
else
    chmod 700 "$HOME/.secrets"
fi

# Terraform shared plugin cache (see dot_zsh.d/60-devops.zsh: TF_PLUGIN_CACHE_DIR)
if [ ! -d "$HOME/.terraform.d/plugin-cache" ]; then
    mkdir -p "$HOME/.terraform.d/plugin-cache"
    echo "  ✓ Created ~/.terraform.d/plugin-cache"
else
    echo "  ✓ ~/.terraform.d/plugin-cache already exists"
fi
