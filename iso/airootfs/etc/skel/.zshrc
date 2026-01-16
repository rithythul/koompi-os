# KOOMPI OS - ZSH Configuration

# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    sudo
    history
    command-not-found
)

# Load oh-my-zsh if available
if [[ -d "$ZSH" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    # Fallback: basic zsh config without oh-my-zsh
    autoload -Uz compinit && compinit

    # Enable colors
    autoload -Uz colors && colors

    # History settings
    HISTFILE=~/.zsh_history
    HISTSIZE=10000
    SAVEHIST=10000
    setopt appendhistory
    setopt sharehistory
    setopt hist_ignore_dups

    # Basic prompt
    PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '

    # Load system plugins if available
    [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
        source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
        source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

# KOOMPI aliases
alias update='sudo koompi-update'
alias install='sudo koompi install'
alias search='koompi search'

# Show system info on first login
if [[ -z "$KOOMPI_WELCOMED" ]]; then
    export KOOMPI_WELCOMED=1
    fastfetch 2>/dev/null || true
fi
