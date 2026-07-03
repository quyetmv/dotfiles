# Workspace navigation
alias ws="cd $HOME/workspace"
alias labs="cd $HOME/workspace/labs"
alias 1..='cd ..'
alias 2..='cd ../..'
alias 3..='cd ../../..'
alias 4..='cd ../../../..'

# Inspect shell modules
alias zshmods='ls ~/.zsh.d'
alias zshnav='less ~/.zsh.d/20-navigation.zsh'
alias zshprompt='less ~/.p10k.zsh'

# File management
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"
alias cls="clear"
alias count='find . -type f | wc -l'
alias cpv='rsync -ah --info=progress2'

# Listing aliases live in 80-modern-tools.zsh (eza with ls fallback)

# Editors and docs

alias tldrf='tldr --list | fzf --preview "tldr {1}" --preview-window=right,60% | xargs tldr'
