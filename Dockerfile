FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USER=quyetmv
ARG UID=1001

# Base packages
RUN apt-get update && apt-get install -y \
    sudo curl git ca-certificates jq zsh \
    && rm -rf /var/lib/apt/lists/*

# Fix: UID 1000 is taken by 'ubuntu' user in 24.04
RUN useradd -m -s /usr/bin/zsh -u ${UID} ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER ${USER}
WORKDIR /home/${USER}

# Suppress zsh-newuser-install prompt
RUN touch ~/.zshrc

# Set chezmoi env vars
ENV CHEZMOI_GIT_NAME="Ma Van Quyet"
ENV CHEZMOI_GIT_EMAIL="quyetmv@ghtk.co"
ENV CHEZMOI_GITHUB_USER="quyetmv"

# Install chezmoi
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
ENV PATH="/home/${USER}/.local/bin:${PATH}"

# Default: Copy local files (allows testing uncommitted changes)
# To pull from GitHub instead, the test-docker.sh will override this or 
# you can use build-args.
COPY --chown=${USER}:${USER} . /home/${USER}/dotfiles

# Init chezmoi (we point to the local copy by default)
RUN chezmoi init --source=/home/${USER}/dotfiles --apply=false

CMD ["zsh"]
