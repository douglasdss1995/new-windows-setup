#!/usr/bin/env bash
# node.sh — Node.js runtime and tooling via mise and pnpm

provision_node() {
  step "Installing Node.js via mise"
  mise use --global node@lts
  eval "$(mise activate bash)"

  if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm
  fi

  pnpm add -g @angular/cli
  pnpm add -g typescript
  pnpm add -g eslint
  pnpm add -g prettier

  success "Node.js and tools installed"
}
