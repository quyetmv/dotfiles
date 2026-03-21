# 80-modern-tools.zsh
# Initializes Starship, Atuin, Zoxide and sets up modern aliases.

# Starship Prompt
# Powerlevel10k remains the default prompt; opt in to Starship explicitly.
if [[ "${DOTFILES_PROMPT:-p10k}" == "starship" ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# Atuin Magical History
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
fi

# Zoxide (Smart CD)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# Eza (Modern LS)
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons --group-directories-first"
    alias ll="eza -lh --icons --group-directories-first"
    alias la="eza -a --icons --group-directories-first"
    alias lt="eza --tree --icons"
fi

# Fastfetch (System Info)
if command -v fastfetch >/dev/null 2>&1; then
    alias fetch="fastfetch"
fi
