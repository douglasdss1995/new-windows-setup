#!/usr/bin/env bash
# system.sh — System update and base dependencies

provision_system_update() {
  step "Updating system packages"
  sudo apt-get update -q && sudo apt-get upgrade -y -q
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
    sudo apt-get install -y -q locales
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
  sudo apt-get install -y -q \
    build-essential \
    curl \
    wget \
    git \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
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

  # Every later step (mise, python, node, cli_tools, docker...) assumes curl,
  # wget and git are on PATH. apt-get can exit 0 yet still be missing some of
  # these — e.g. an unresolvable package aborting the whole transaction (seen
  # with the now-removed software-properties-common), or the install getting
  # interrupted (Ctrl+C) without apt surfacing it as a failure. Verify
  # explicitly instead of trusting apt's exit code, so a broken base install
  # is reported as a failed step (and retried on rerun) instead of silently
  # cascading into "command not found" across every later step.
  local missing=()
  for bin in curl wget git; do
    command -v "$bin" &>/dev/null || missing+=("$bin")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "Base dependencies reported success but missing: ${missing[*]} - rerun the script"
    return 1
  fi

  success "Base dependencies installed"
}
