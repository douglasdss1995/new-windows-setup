#!/usr/bin/env bash
# cli_tools.sh — Modern CLI tools (ripgrep, fd, bat, fzf, zoxide, delta, eza, jq, yq, gh, direnv)

provision_cli_tools() {
  step "Installing CLI tools"

  if ! command -v rg &>/dev/null; then
    sudo apt-get install -y -qq ripgrep
  fi

  if ! command -v fd &>/dev/null; then
    sudo apt-get install -y -qq fd-find
    if ! command -v fd &>/dev/null; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    fi
  fi

  if ! command -v bat &>/dev/null; then
    sudo apt-get install -y -qq bat
    if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
      mkdir -p "$HOME/.local/bin"
      ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    fi
  fi

  if ! command -v fzf &>/dev/null; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all --no-bash --no-fish
  fi

  if ! command -v zoxide &>/dev/null; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi

  if ! command -v delta &>/dev/null; then
    local DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep tag_name | cut -d'"' -f4)
    curl -sLo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
    sudo dpkg -i /tmp/delta.deb
    rm /tmp/delta.deb
  fi

  if ! command -v eza &>/dev/null; then
    sudo apt-get install -y -qq gpg
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq && sudo apt-get install -y -qq eza
  fi

  if ! command -v jq &>/dev/null; then
    sudo apt-get install -y -qq jq
  fi

  if ! command -v yq &>/dev/null; then
    local YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d'"' -f4)
    sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
    sudo chmod +x /usr/local/bin/yq
  fi

  if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh
  fi

  if ! command -v direnv &>/dev/null; then
    sudo apt-get install -y -qq direnv
  fi

  success "CLI tools installed"
}
