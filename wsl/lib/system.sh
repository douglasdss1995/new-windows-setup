#!/usr/bin/env bash
# system.sh — System update and base dependencies

provision_system_update() {
  step "Updating system packages"
  sudo apt-get update -qq && sudo apt-get upgrade -y -qq
  success "System updated"
}

# Debian's WSL rootfs ships without a UTF-8 locale generated (Ubuntu's rootfs
# sets C.UTF-8 out of the box). Without this, Python's Click library (used by
# black, pre-commit, etc.) raises "RuntimeError: Click will abort further
# execution because Python 3 was configured to use ASCII as encoding" and
# apt/perl print "Setting locale failed" warnings on every command.
provision_locale() {
  step "Configuring locale (en_US.UTF-8)"
  if ! locale -a 2>/dev/null | grep -qi 'en_US.utf8'; then
    sudo apt-get install -y -qq locales
    sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    success "Locale en_US.UTF-8 generated and set as default"
  else
    warn "Locale en_US.UTF-8 already present, skipping"
  fi
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
