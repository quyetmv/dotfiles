#!/usr/bin/env bash

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

ACTION="${1:-menu}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

is_wsl() {
    [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]] || grep -qi microsoft /proc/version 2>/dev/null
}

preflight() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root. Use a sudo-capable user."
        exit 1
    fi
    if ! sudo -v; then
        log_error "Sudo privileges required."
        exit 1
    fi
}

usage() {
    cat <<'EOF'
Usage: ./scripts/setup-linux.sh <command>

Commands:
  menu       Show the interactive menu
  base       Install the default Linux workstation baseline
  packages   Install apt packages and locale support
  mise       Install mise
  extras     Install shell extras (powerlevel10k, z, lsd, lazygit)
  docker     Install Docker CE
  ansible    Install ansible config and directories
  wsl        Install WSL extras (only when running under WSL)
  all        Install base + Docker + WSL extras when applicable
  help       Show this help
EOF
}

ensure_utf8_locale() {
    if command_exists locale && locale -a 2>/dev/null | grep -qi '^en_US\.utf-8$'; then
        return 0
    fi

    log_info "Attempting to generate en_US.UTF-8 locale..."
    if command_exists locale-gen; then
        sudo locale-gen en_US.UTF-8 || true
    fi

    if [[ -f /etc/locale.gen ]]; then
        sudo sed -i 's/^# \(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        sudo locale-gen || true
    fi

    if command_exists update-locale; then
        sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 || true
    fi
}

install_fonts() {
    log_info "Installing MesloLGS NF fonts..."
    local font_dir="$HOME/.local/share/fonts/MesloLGS-NF"
    if [[ ! -f "$font_dir/MesloLGS NF Regular.ttf" ]]; then
        mkdir -p "$font_dir"
        curl -fsSLo "$font_dir/MesloLGS NF Regular.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        curl -fsSLo "$font_dir/MesloLGS NF Bold.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        curl -fsSLo "$font_dir/MesloLGS NF Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        curl -fsSLo "$font_dir/MesloLGS NF Bold Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
        if command_exists fc-cache; then
            fc-cache -f "$font_dir" >/dev/null 2>&1 || true
        fi
        log_success "MesloLGS NF installed to $font_dir"
    else
        log_info "MesloLGS NF already installed."
    fi
}

install_apt_packages() {
    log_info "Installing default apt packages..."
    local pkgs=(
        apt-transport-https
        bash-completion
        ca-certificates
        bison
        build-essential
        curl
        dbus
        dos2unix
        fd-find
        file
        fonts-cascadia-code
        fzf
        git
        gnupg
        htop
        iftop
        iotop
        jq
        locales
        lsb-release
        mosh
        mysql-client
        ncdu
        net-tools
        neovim
        nfs-common
        numactl
        procps
        redis
        ripgrep
        software-properties-common
        tcpdump
        telnet
        tmux
        unzip
        vim
        wget
        xclip
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
    )

    sudo apt-get update -qq
    if sudo apt-get install -y "${pkgs[@]}"; then
        log_success "Default packages installed."
    else
        log_warning "Some packages failed to install."
    fi

    ensure_utf8_locale

    if command_exists fdfind && ! command_exists fd; then
        sudo mkdir -p /usr/local/bin
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
        log_info "Created symlink: fd -> fdfind"
    fi
}

install_mise() {
    log_info "Installing mise..."
    if command_exists mise; then
        log_info "mise already installed: $(mise --version)"
        return 0
    fi

    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    log_success "mise installed: $(mise --version)"
}

install_zsh_extras() {
    log_info "Installing zsh extras..."

    if ! command_exists git; then
        log_error "git is required before installing shell extras."
        return 1
    fi

    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        mkdir -p "$(dirname "$p10k_dir")"
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_success "Powerlevel10k installed"
    else
        log_info "Powerlevel10k already installed"
    fi

    local z_dir="$HOME/.local/share/z"
    if [[ ! -d "$z_dir" ]]; then
        mkdir -p "$(dirname "$z_dir")"
        git clone --depth=1 https://github.com/rupa/z.git "$z_dir"
        log_success "z installed"
    else
        log_info "z already installed"
    fi

    install_fonts

    log_info "lazygit, lsd, and bat are now managed by mise (see dot_tool-versions)."
    log_warning "Set your terminal font to 'MesloLGS NF' to avoid broken Powerlevel10k glyphs."
    log_success "Zsh extras done."
}

install_docker() {
    log_info "Installing Docker CE..."

    sudo install -d -m 0755 /etc/apt/keyrings
    sudo curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq

    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    if command_exists systemctl; then
        sudo systemctl enable --now docker || true
    fi
    sudo usermod -aG docker "$USER"

    log_success "Docker installed."
    log_warning "Log out/in for docker group membership to take effect."
}

setup_ansible_config() {
    log_info "Setting up Ansible configuration..."

    local repo_root
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local src_cfg="$repo_root/ansible.cfg"
    local dest_cfg="$HOME/.ansible.cfg"

    mkdir -p "$HOME/.ansible" "$HOME/.ansible-retry" "$HOME/.ansible/facts.d" "$HOME/.ssh"

    if [[ ! -f "$HOME/.ansible/vault" ]]; then
        touch "$HOME/.ansible/vault"
        chmod 600 "$HOME/.ansible/vault"
    fi

    if [[ -f "$src_cfg" ]]; then
        install -m 0644 "$src_cfg" "$dest_cfg"
        log_success "ansible.cfg -> $dest_cfg"
    else
        log_warning "ansible.cfg not found at $src_cfg; skipping."
    fi
}

wsl_basics() {
    if ! is_wsl; then
        log_info "Not running under WSL; skipping WSL extras."
        return 0
    fi

    log_info "WSL basics: oh-my-zsh..."
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh (unattended)..."
        RUNZSH=no CHSH=no \
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    else
        log_info "Oh My Zsh already installed."
    fi
    log_warning "To make zsh default: chsh -s \$(which zsh)"
    log_success "WSL basics done."
}

run_steps() {
    local failed=()
    local step

    for step in "$@"; do
        local name="${step%%:*}"
        local func="${step##*:}"
        log_info "-> $name"
        if ! "$func"; then
            failed+=("$name")
        fi
    done

    echo ""
    if [[ ${#failed[@]} -eq 0 ]]; then
        log_success "Requested setup completed."
    else
        log_warning "Some steps failed: ${failed[*]}"
        return 1
    fi
}

install_base() {
    run_steps \
        "apt packages:install_apt_packages" \
        "mise:install_mise" \
        "zsh extras:install_zsh_extras" \
        "ansible config:setup_ansible_config"
}

install_all() {
    run_steps \
        "apt packages:install_apt_packages" \
        "mise:install_mise" \
        "zsh extras:install_zsh_extras" \
        "docker:install_docker" \
        "ansible config:setup_ansible_config" \
        "wsl basics:wsl_basics"
}

show_menu() {
    echo "############################################################"
    echo "#  Linux Setup Script by quyetmv                           #"
    echo "############################################################"
    echo ""
    echo "Commands:"
    echo " 0  - Default packages (apt)"
    echo " 1  - mise"
    echo " 2  - Zsh extras (powerlevel10k, z, lsd, lazygit)"
    echo " 3  - Docker CE"
    echo " 4  - Ansible config setup"
    echo " 5  - WSL basics"
    echo " 6  - Base install"
    echo " 7  - Install ALL"
    echo ""
}

run_interactive() {
    preflight
    show_menu
    read -r -p "Enter choice: " choice
    echo ""

    case "$choice" in
        0) install_apt_packages ;;
        1) install_mise ;;
        2) install_zsh_extras ;;
        3) install_docker ;;
        4) setup_ansible_config ;;
        5) wsl_basics ;;
        6) install_base ;;
        7) install_all ;;
        *) log_error "Invalid choice."; exit 1 ;;
    esac

    echo ""
    log_success "Done."
}

case "$ACTION" in
    menu|--menu)
        run_interactive
        ;;
    help|--help|-h)
        usage
        ;;
    base|--base)
        preflight
        install_base
        ;;
    all|--all)
        preflight
        install_all
        ;;
    packages|--packages)
        preflight
        install_apt_packages
        ;;
    mise|--mise)
        preflight
        install_mise
        ;;
    extras|--extras)
        preflight
        install_zsh_extras
        ;;
    docker|--docker)
        preflight
        install_docker
        ;;
    ansible|--ansible)
        preflight
        setup_ansible_config
        ;;
    fonts|--fonts)
        install_fonts
        ;;
    wsl|--wsl)
        preflight
        wsl_basics
        ;;
    *)
        log_error "Unknown command: $ACTION"
        echo ""
        usage
        exit 1
        ;;
esac
