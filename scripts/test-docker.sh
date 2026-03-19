#!/usr/bin/env bash
# ============================================================================
# test-docker.sh — Test dotfiles in a clean Ubuntu container
#
# Usage:
#   ./test-docker.sh              # Local test (interactive)
#   ./test-docker.sh --github     # GitHub test (interactive)
#   ./test-docker.sh --full       # Local full setup + validate
#   ./test-docker.sh --full-gh    # GitHub full setup + validate
# ============================================================================

set -euo pipefail

IMAGE_NAME="dotfiles-test"
MODE="${1:-}"
REPO_URL="https://github.com/quyetmv/dotfiles.git"

build_local() {
    echo "🐳 Building Docker image with LOCAL files..."
    docker build -t "$IMAGE_NAME" -f Dockerfile .
}

build_github() {
    echo "🐳 Building Docker image (GitHub mode)..."
    # We create a temporary Dockerfile that doesn't COPY but pulls
    sed 's|COPY --chown=${USER}:${USER} . /home/${USER}/dotfiles|RUN git clone '"$REPO_URL"' /home/${USER}/dotfiles|' Dockerfile > Dockerfile.gh
    docker build -t "$IMAGE_NAME-gh" -f Dockerfile.gh .
    rm Dockerfile.gh
}

run_full() {
    local target_image=$1
    local source_desc=$2
    
    echo "🚀 Running full setup and validation ($source_desc)..."
    docker run --rm -it "$target_image" zsh -c '
        echo "=== Step 1: setup-linux.sh (apt packages) ==="
        cd $HOME/dotfiles
        ./scripts/setup-linux.sh packages

        echo ""
        echo "=== Step 2: chezmoi apply ==="
        # Re-init to make sure we use the right source
        chezmoi init --source=$HOME/dotfiles --apply --no-tty

        echo ""
        echo "=== Step 3: test-chezmoi.sh ==="
        CHEZMOI_SOURCE=$HOME/dotfiles bash $HOME/dotfiles/scripts/test-chezmoi.sh

        echo ""
        echo "=== Step 4: validate-setup.sh ==="
        bash $HOME/dotfiles/scripts/validate-setup.sh

        echo ""
        echo "✅ Full test complete!"
        exec zsh
    '
}

case "$MODE" in
    --github)
        build_github
        docker run --rm -it "$IMAGE_NAME-gh" zsh
        ;;
    --full)
        build_local
        run_full "$IMAGE_NAME" "LOCAL"
        ;;
    --full-gh)
        build_github
        run_full "$IMAGE_NAME-gh" "GITHUB"
        ;;
    *)
        build_local
        echo "🐚 Starting interactive shell (LOCAL)..."
        echo ""
        echo "  Inside the container, you can run:"
        echo "    chezmoi apply --source=\$HOME/dotfiles --force"
        echo "    cd \$HOME/dotfiles && make linux"
        echo "    cd \$HOME/dotfiles && make test"
        echo ""
        docker run --rm -it "$IMAGE_NAME" zsh
        ;;
esac
