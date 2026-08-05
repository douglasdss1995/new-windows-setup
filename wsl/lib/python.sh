#!/usr/bin/env bash
# python.sh — Python runtime and tooling via mise and uv

provision_python() {
  step "Installing Python via mise"
  mise use --global python@latest
  eval "$(mise activate bash)"

  if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  uv tool install poetry
  uv tool install black
  uv tool install ruff
  uv tool install mypy
  uv tool install pytest
  uv tool install ipython
  uv tool install httpie
  uv tool install pre-commit

  for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if ! grep -q '.local/bin' "$RC" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
    fi
  done

  success "Python and tools installed"
}
