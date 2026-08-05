#!/usr/bin/env bash
# docker.sh — Docker daemon installation and systemd configuration

provision_docker() {
  step "Installing Docker"
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    success "Docker installed - log out/in to use without sudo"
  else
    warn "Docker already installed, skipping"
  fi

  sudo systemctl enable docker
  sudo systemctl start docker 2>/dev/null || true
  success "Docker configured to start automatically via systemd"
}
