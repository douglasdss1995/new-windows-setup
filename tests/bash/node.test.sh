#!/usr/bin/env bash
# Tests for wsl/lib/node.sh: Angular CLI must be installed natively through
# mise, and the step must fail when a name still resolves to a Windows binary.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/wsl/lib/logging.sh"
source "$ROOT/wsl/lib/node.sh"

PASS=0
FAIL=0
assert() { # assert <description> <command...>
  local desc="$1"; shift
  if "$@"; then
    PASS=$((PASS + 1)); echo "  ok   $desc"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL $desc"
  fi
}
logged() { grep -qxF -- "$1" "$LOG"; }
not_logged() { ! grep -qxF -- "$1" "$LOG"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG="$WORK/calls.log"

# Stub tool: records "<name> <args>" in $LOG. Uses only shell builtins so the
# restricted PATH below is enough.
make_stub() { # make_stub <dir> <name>
  mkdir -p "$1"
  printf '#!/bin/sh\necho "%s $*" >> "%s"\n' "$2" "$LOG" > "$1/$2"
  chmod +x "$1/$2"
}

LINUX="$WORK/linux"      # stands in for ~/.local/share/mise/... (native)
WINDOWS="$WORK/mnt/c"    # stands in for /mnt/c/... (Windows shims)
for t in mise npm pnpm ng node; do make_stub "$LINUX" "$t"; done
export WINDOWS_MOUNT_PREFIX="$WORK/mnt/"

echo "is_native_command"
assert "native binary is native"        env PATH="$LINUX:/usr/bin:/bin" bash -c "source '$ROOT/wsl/lib/node.sh'; is_native_command ng"
make_stub "$WINDOWS" ng
assert "binary under the Windows mount is not native" \
  env PATH="$WINDOWS:/usr/bin:/bin" bash -c "source '$ROOT/wsl/lib/node.sh'; ! is_native_command ng"
assert "missing binary is not native"   env PATH="/nonexistent" "$BASH" -c "source '$ROOT/wsl/lib/node.sh'; ! is_native_command ng"

echo "provision_node: everything native"
: > "$LOG"
PATH="$LINUX:/usr/bin:/bin" provision_node >/dev/null 2>&1; rc=$?
assert "succeeds"                                  [ "$rc" -eq 0 ]
assert "installs Angular CLI through mise"         logged "mise use --global npm:@angular/cli"
assert "does not use pnpm for Angular CLI"         not_logged "pnpm add -g @angular/cli"
assert "still installs typescript via pnpm"        logged "pnpm add -g typescript"
assert "does not reinstall a native pnpm"          not_logged "npm install -g pnpm"

echo "provision_node: Windows pnpm shim wins the lookup"
: > "$LOG"
rm -f "$LINUX/pnpm"; make_stub "$WINDOWS" pnpm
PATH="$WINDOWS:$LINUX:/usr/bin:/bin" provision_node >/dev/null 2>&1; rc=$?
assert "installs a Linux pnpm first"               logged "npm install -g pnpm"
assert "step fails because pnpm is still Windows"  [ "$rc" -eq 1 ]

echo "provision_node: ng missing on Linux"
: > "$LOG"
rm -f "$LINUX/ng" "$WINDOWS/ng" "$WINDOWS/pnpm"; make_stub "$LINUX" pnpm
PATH="$LINUX:/usr/bin:/bin" provision_node >/dev/null 2>&1; rc=$?
assert "step fails when ng is not installed"       [ "$rc" -eq 1 ]

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
