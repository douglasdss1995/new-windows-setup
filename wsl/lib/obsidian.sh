#!/usr/bin/env bash
# obsidian.sh — Obsidian (WSLg) install
#
# Same idea as GitKraken: vaults on the WSL (ext4) filesystem need Obsidian
# running *inside* WSL via WSLg, while vaults on the Windows filesystem use the
# separate Windows install (setup-windows.ps1). Both installs coexist.
# The .deb is taken from the latest GitHub release (the file name carries the
# version, so the asset URL is looked up through the releases API).

OBSIDIAN_RELEASE_API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"

provision_obsidian() {
  step "Installing Obsidian (WSLg)"

  if command -v obsidian &>/dev/null; then
    warn "Obsidian already installed, skipping"
    return
  fi

  local arch deb_arch
  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64|arm64) deb_arch="$arch" ;;
    *) warn "Obsidian has no .deb for $arch - skipping"; return ;;
  esac

  info "Looking up the latest Obsidian release..."
  local url
  url="$(curl -fsSL "$OBSIDIAN_RELEASE_API" \
    | grep -oE "https://[^\"]+/obsidian_[0-9.]+_${deb_arch}\.deb" | head -n 1)" || true
  if [ -z "$url" ]; then
    warn "Could not find the Obsidian .deb in the latest GitHub release"
    return 1
  fi

  local deb_path="/tmp/obsidian_${deb_arch}.deb"
  info "Downloading Obsidian (~110 MB) - this can take a few minutes on a slow connection..."
  curl -fSL -o "$deb_path" "$url"
  sudo apt-get install -y -q "$deb_path" || sudo apt-get --fix-broken install -y -q
  rm -f "$deb_path"

  command -v obsidian &>/dev/null || { warn "Obsidian install did not produce the 'obsidian' command"; return 1; }
  success "Obsidian installed - launch from WSL with: obsidian"
}
