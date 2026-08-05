#!/usr/bin/env bash
# system.sh — System update and base dependencies

provision_system_update() {
  step "Updating system packages"
  sudo apt-get update -qq && sudo apt-get upgrade -y -qq
  success "System updated"
}

provision_base_deps() {
  step "Installing base dependencies"
  sudo apt-get install -y -qq \
    build-essential \
    curl \
    wget \
    git \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    libssl-dev \
    libffi-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    libxml2-dev \
    libxmlsec1-dev \
    liblzma-dev \
    tk-dev \
    xz-utils \
    llvm \
    make \
    gpg
  success "Base dependencies installed"
}
