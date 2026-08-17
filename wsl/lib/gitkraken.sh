#!/usr/bin/env bash
# gitkraken.sh — GitKraken Desktop (WSLg) install + keyboard layout fix
#
# GitKraken has no unified Windows/WSL integration: repos on the WSL (ext4)
# filesystem need GitKraken running *inside* WSL via WSLg, while repos on
# the Windows filesystem use the separate Windows install (already handled
# by setup-windows.ps1 / GitTools.GitKraken). Both installs coexist.

GITKRAKEN_DEB_URL="https://release.gitkraken.com/linux/gitkraken-amd64.deb"

provision_gitkraken() {
  step "Installing GitKraken Desktop (WSLg)"

  if command -v gitkraken &>/dev/null; then
    warn "GitKraken already installed, skipping"
    return
  fi

  local deb_path="/tmp/gitkraken-amd64.deb"
  info "Downloading GitKraken (~150 MB) - this can take a few minutes on a slow connection..."
  curl -fSL -o "$deb_path" "$GITKRAKEN_DEB_URL"
  sudo apt-get install -y -q "$deb_path" || sudo apt-get --fix-broken install -y -q
  rm -f "$deb_path"

  success "GitKraken installed - launch from WSL with: gitkraken"
}

# WSLg delegates GUI keyboard translation to the distro instead of the
# Windows input language, and silently falls back to en_US when it can't
# map a non-standard layout (e.g. Brazilian ABNT2) - breaking accents in
# GUI apps like GitKraken. /home/wslg/.config is bind-mounted from the
# WSLg system distro into every WSL distro, so it's writable from here.
# See: https://github.com/microsoft/wslg/issues/1184
provision_keyboard_layout() {
  step "Configuring WSLg keyboard layout ($KEYBOARD_LAYOUT/$KEYBOARD_VARIANT)"

  local weston_dir="/home/wslg/.config"
  local weston_ini="$weston_dir/weston.ini"

  if [ ! -d "$weston_dir" ]; then
    warn "WSLg config dir not found (not running under WSLg) - skipping"
    return
  fi

  if ! grep -q '^\[keyboard\]' "$weston_ini" 2>/dev/null; then
    cat >> "$weston_ini" << EOF

[keyboard]
keymap_layout=$KEYBOARD_LAYOUT
keymap_variant=$KEYBOARD_VARIANT
EOF
  else
    sed -i "/^\[keyboard\]/,/^\[/ s/^keymap_layout=.*/keymap_layout=$KEYBOARD_LAYOUT/" "$weston_ini"
    sed -i "/^\[keyboard\]/,/^\[/ s/^keymap_variant=.*/keymap_variant=$KEYBOARD_VARIANT/" "$weston_ini"
  fi

  # Reload weston so it picks up the new keymap without a full WSL restart.
  pkill -HUP weston 2>/dev/null || true

  # X11 fallback (some GUI apps ignore weston's Wayland keymap) - reapplied
  # on every shell start since it doesn't persist across WSL restarts.
  ensure_line "$HOME/.zshrc"  "setxkbmap $KEYBOARD_LAYOUT -variant $KEYBOARD_VARIANT 2>/dev/null"
  ensure_line "$HOME/.bashrc" "setxkbmap $KEYBOARD_LAYOUT -variant $KEYBOARD_VARIANT 2>/dev/null"

  success "Keyboard layout set to $KEYBOARD_LAYOUT/$KEYBOARD_VARIANT (Wayland + X11 fallback)"
}
