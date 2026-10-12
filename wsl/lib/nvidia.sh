#!/usr/bin/env bash
# nvidia.sh — NVIDIA Container Toolkit (GPU access for Docker containers)
#
# Prerequisite lives on the Windows side: the regular NVIDIA Windows driver
# exposes the GPU to WSL 2. Never install a Linux NVIDIA driver inside WSL.

# True when the Windows driver is exposing the GPU to this WSL distro.
# Separate function so tests can override it.
_nvidia_gpu_visible() {
  command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null
}

provision_nvidia_container_toolkit() {
  step "Installing NVIDIA Container Toolkit"

  if ! command -v docker &>/dev/null; then
    warn "Docker not found - NVIDIA Container Toolkit needs it (run without --skip-docker). Skipping"
    return 0
  fi

  if ! _nvidia_gpu_visible; then
    warn "nvidia-smi found no GPU inside WSL - install the NVIDIA driver on Windows (with WSL support) and run 'wsl --update'. Skipping"
    return 0
  fi

  if command -v nvidia-ctk &>/dev/null; then
    warn "NVIDIA Container Toolkit already installed, skipping package install"
  else
    info "Adding NVIDIA apt repository"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null

    info "Installing nvidia-container-toolkit (~100 MB) - this can take a few minutes..."
    sudo apt-get update -q
    sudo apt-get install -y -q nvidia-container-toolkit

    # apt can exit 0 without installing anything (see provision_base_deps)
    if ! command -v nvidia-ctk &>/dev/null; then
      warn "nvidia-ctk not found after install"
      return 1
    fi
  fi

  info "Registering the nvidia runtime in /etc/docker/daemon.json"
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker

  success "NVIDIA Container Toolkit configured - test: docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu24.04 nvidia-smi"
}
