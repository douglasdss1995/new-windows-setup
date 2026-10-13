#!/usr/bin/env bash
# node.sh — Node.js runtime and tooling via mise and pnpm

# True when $1 resolves to something other than a Windows binary. With
# appendWindowsPath=true the Windows PATH is appended inside WSL, so a name with
# no Linux build resolves to a Windows shim under /mnt/c (see docs/wsl-conf.md).
# WINDOWS_MOUNT_PREFIX only exists so tests can fake a Windows mount.
is_native_command() {
  local resolved
  resolved="$(command -v "$1" 2>/dev/null)" || return 1
  [[ "$resolved" != "${WINDOWS_MOUNT_PREFIX:-/mnt/}"* ]]
}

provision_node() {
  step "Installing Node.js via mise"
  mise use --global node@lts
  eval "$(mise activate bash)"

  # A Windows pnpm shim would satisfy a plain `command -v pnpm` and then
  # install every "global" package on the Windows side instead of in WSL.
  if ! is_native_command pnpm; then
    npm install -g pnpm
    hash -r
  fi

  # Angular CLI through mise, not pnpm: mise puts the Linux `ng` ahead of any
  # Windows shim, and does not depend on pnpm's global bin dir being on PATH.
  mise use --global npm:@angular/cli
  hash -r

  pnpm add -g typescript
  pnpm add -g eslint
  pnpm add -g prettier

  # Same trap as in provision_base_deps: the install commands can exit 0 and
  # still leave a Windows binary answering to the name, which later hangs the
  # shell (completion at startup) or installs into the wrong OS.
  local tool missing=()
  for tool in node pnpm ng; do
    is_native_command "$tool" || missing+=("$tool")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    warn "Not resolving to a Linux binary inside WSL: ${missing[*]} (check 'type -a <tool>' and mise activation)"
    return 1
  fi

  success "Node.js and tools installed"
}
