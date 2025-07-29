#!/bin/bash

set -e

echo "=========================================="
echo "02 - Terminal Setup"
echo "=========================================="

# Change default shell to zsh
echo "Setting zsh as default shell..."
chsh -s $(which zsh)

# Create .zshrc configuration
echo "Creating .zshrc configuration..."
cat >~/.zshrc <<'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="half-life"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    history-substring-search
)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='nano'
export LANG=en_US.UTF-8

# Aliases
alias ll='eza -alF --color=always --group-directories-first'
alias la='eza -a --color=always --group-directories-first'
alias l='eza -F --color=always --group-directories-first'
alias ls='eza --color=always --group-directories-first'
alias lt='eza -aT --color=always --group-directories-first'
alias l.='eza -a | grep -E "^\."'

# File operations
alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'

# Better cat with bat
alias cat='bat --style=plain'
alias catn='bat --style=plain --paging=never'
alias bathelp='bat --plain --language=help'

# Find files with fd
alias find='fd'

# Yazi file manager
alias fm='yazi'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# System info
alias df='df -h'
alias free='free -m'
alias np='nano -w PKGBUILD'
alias more='less'

# ls
alias ls='eza --icons --git --color=always --group-directories-first --tree --level=2 --no-permissions --no-user --no-time'

# read files
alias cat='bat --paging=never'

# FZF configuration
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range=:500 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Yazi shell wrapper
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# GIT_ROOT is a global variable, so 'local' is not used here.
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

# A powerful, context-aware project finder that displays clean, relative paths.
# If run inside a git repository, it searches only within that project.
# Otherwise, it searches from your home directory.
# Usage: Type 'ff' in your terminal and press Enter.
ff() {
    # Attempt to find the root of the current git repository. 
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    
    local search_path
    # Check if we are inside a git repository.
    if [[ -n "$git_root" ]]; then
        # If yes, set the search path to the project's root directory.
        search_path="$git_root"
    else
        # If no, fall back to searching from the home directory.
        search_path="$HOME"
    fi

    # We need to export the search_path so the fzf preview subshell can access it.
    export FZF_FF_SEARCH_PATH="$search_path"

    # Find directories, strip the base path for a clean display, and pipe to fzf.
    local selected_relative_path
    selected_relative_path=$(fd --type d . "$search_path" --hidden --exclude .git --exclude node_modules \
        | sed "s|^$search_path/||" \
        | fzf \
            --preview 'eza --tree --color=always --icons=always --level=2 "$FZF_FF_SEARCH_PATH"/{}' \
            --preview-window 'right:50%' \
            --height '80%' \
            --border 'rounded' \
            --header 'Project Finder | Press Enter to select')

    # If a directory was selected (i.e., you pressed Enter)...
    if [[ -n "$selected_relative_path" ]]; then
        # ...reconstruct the full path by prepending the search_path.
        local full_path="$search_path/$selected_relative_path"
        # Change the current directory of your terminal to that full path.
        cd "$full_path" || return
        # Optional: clear the screen and show a tree of the new location.
        clear
        eza --tree --icons=always --level=2 # Corrected eza flag
    fi
}
EOF

# Install Oh My Zsh
echo "Installing Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k theme
echo "Installing Powerlevel10k theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k 2>/dev/null || true

# Install zsh plugins (if not already installed via package manager)
echo "Setting up zsh plugins..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Create symbolic links for fd (Ubuntu/Debian uses fd-find)
echo "Creating fd symlink..."
if command -v fd-find >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  sudo ln -sf $(which fd-find) /usr/local/bin/fd
fi

# Set up bat config
echo "Setting up bat configuration..."
mkdir -p ~/.config/bat
cat >~/.config/bat/config <<'EOF'
--theme="TwoDark"
--italic-text=always
--style="numbers,changes,header"
--pager="less -FR"
EOF

echo "Terminal setup complete!"
echo "Please run 'source ~/.zshrc' or restart your terminal to apply changes."
echo "Run 'p10k configure' to customize your prompt appearance."

