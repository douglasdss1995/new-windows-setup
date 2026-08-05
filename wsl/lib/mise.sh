#!/usr/bin/env bash
# mise.sh — Universal runtime version manager (mise) installation and configuration

provision_mise_install() {
  step "Installing mise"
  if ! command -v mise &>/dev/null; then
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
    success "mise installed"
  else
    warn "mise already installed, updating"
    mise self-update || true
  fi

  # Create .zshenv (always read by zsh, interactive or not)
  # This ensures PATH and mise shims are available even in non-interactive shells
  if [ ! -f "$HOME/.zshenv" ]; then
    cat > "$HOME/.zshenv" << 'EOF'
# .zshenv — always read by zsh (interactive and non-interactive)
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
EOF
    success ".zshenv created"
  else
    # Check if .zshenv already has the correct PATH configuration
    if ! grep -q '.local/share/mise/shims' "$HOME/.zshenv" 2>/dev/null; then
      # Append the mise shims path if not present
      echo '' >> "$HOME/.zshenv"
      echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"' >> "$HOME/.zshenv"
      success ".zshenv updated with mise shims"
    fi
  fi

  for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if ! grep -q 'mise activate' "$RC" 2>/dev/null; then
      echo '' >> "$RC"
      echo '# mise - runtime version manager' >> "$RC"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
      echo 'eval "$(mise activate bash)"' >> "$RC"
    fi
  done

  if grep -q 'mise activate bash' "$HOME/.zshrc"; then
    sed -i 's/mise activate bash/mise activate zsh/' "$HOME/.zshrc"
  fi

  success "mise configured in shell"
}
