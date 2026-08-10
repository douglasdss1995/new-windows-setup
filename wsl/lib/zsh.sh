#!/usr/bin/env bash
# zsh.sh — Zsh, Oh My Zsh, plugins, and zshrc configuration

provision_zsh_ohmyzsh() {
  step "Installing Zsh + Oh My Zsh"
  sudo apt-get install -y -qq zsh

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "Oh My Zsh installed"
  else
    warn "Oh My Zsh already installed, skipping"
  fi

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi

  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
  fi

  success "Zsh plugins installed"

  if [ "$SHELL" != "$(which zsh)" ]; then
    sudo chsh -s "$(which zsh)" "$USER"
    success "Zsh set as default shell"
  fi
}

provision_zshrc_config() {
  step "Configuring .zshrc"

  local ZSHRC="$HOME/.zshrc"

  if grep -q '^plugins=' "$ZSHRC"; then
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions z fzf)/' "$ZSHRC"
  fi

  if ! grep -q '# === provision aliases ===' "$ZSHRC"; then
    cat >> "$ZSHRC" << 'EOF'

# === provision aliases ===

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='eza -lah --git --icons'
alias ls='eza --icons'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'
alias duh='du -h --max-depth=1 . | sort -rh'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Django
alias pm='python manage.py'
alias pmr='python manage.py runserver'
alias pmm='python manage.py migrate'
alias pmmk='python manage.py makemigrations'
alias pmsh='python manage.py shell'

# Python
alias py='python'
alias pip='uv pip'
alias venv='uv venv'

# Docker
alias dk='docker'
alias dkc='docker compose'
alias dkps='docker ps'
alias dkpsa='docker ps -a'

# Providers (PostgreSQL, Redis, pgAdmin, MinIO, Portainer)
alias pvup='docker container prune -f 2>/dev/null; docker compose -f ~/providers/docker-compose.yml up -d --remove-orphans --force-recreate'
alias pvdown='docker compose -f ~/providers/docker-compose.yml down --remove-orphans; docker container prune -f 2>/dev/null'
alias pvlogs='docker compose -f ~/providers/docker-compose.yml logs -f'
alias pvps='docker compose -f ~/providers/docker-compose.yml ps'
alias pvrestart='docker compose -f ~/providers/docker-compose.yml restart'

# zoxide as cd
eval "$(zoxide init zsh)"

# fzf keybindings
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# direnv
eval "$(direnv hook zsh)"

# === mnt guard === (skip mise/direnv inside Windows-mounted paths, e.g. /mnt/c - avoids slow 9P I/O)
for _fn in _mise_hook_precmd _mise_hook_chpwd _direnv_hook; do
  if (( ${+functions[$_fn]} )); then
    functions -c "$_fn" "__${_fn}_orig"
    eval "${_fn}() { [[ \$PWD == /mnt/* ]] && return; __${_fn}_orig \"\$@\"; }"
  fi
done
unset _fn

EOF
  fi

  if ! grep -q '# === provision aliases ===' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'EOF'

# === provision aliases ===
alias duh='du -h --max-depth=1 . | sort -rh'
alias ll='ls -lah'
EOF
  fi

  if ! grep -q 'direnv hook bash' "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# direnv' >> "$HOME/.bashrc"
    echo 'eval "$(direnv hook bash)"' >> "$HOME/.bashrc"
  fi

  if ! grep -q '# === mnt guard ===' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'EOF'

# === mnt guard === (skip mise/direnv inside Windows-mounted paths, e.g. /mnt/c - avoids slow 9P I/O)
for _fn in _mise_hook_prompt_command _mise_hook_chpwd _direnv_hook; do
  if declare -f "$_fn" >/dev/null 2>&1; then
    eval "$(declare -f "$_fn" | sed "1s/^$_fn ()/__${_fn}_orig()/")"
    eval "${_fn}() { [[ \$PWD == /mnt/* ]] && return; __${_fn}_orig \"\$@\"; }"
  fi
done
unset _fn
EOF
  fi

  success ".zshrc configured"
}
