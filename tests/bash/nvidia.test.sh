#!/usr/bin/env bash
# Tests for wsl/lib/nvidia.sh: the step must skip cleanly (exit 0, no sudo/apt)
# when Docker or the GPU is missing, and stay opt-in in setup-wsl.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/wsl/lib/logging.sh"
source "$ROOT/wsl/lib/nvidia.sh"

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
contains() { [[ "$1" == *"$2"* ]]; }
not_contains() { [[ "$1" != *"$2"* ]]; }

# Any sudo call means the step did not skip — fail loudly instead of touching the system.
sudo() { echo "SUDO CALLED: $*"; return 99; }

# Fake PATH with a "docker" stub only, so `command -v docker` is deterministic.
STUBS="$(mktemp -d)"
printf '#!/bin/sh\nexit 0\n' > "$STUBS/docker"; chmod +x "$STUBS/docker"
trap 'rm -rf "$STUBS"' EXIT

echo "no GPU visible"
_nvidia_gpu_visible() { return 1; }
out="$(PATH="$STUBS:$PATH" provision_nvidia_container_toolkit 2>&1)"; rc=$?
assert "exits 0"                    [ "$rc" -eq 0 ]
assert "warns about missing GPU"    contains "$out" "found no GPU"
assert "does not call sudo"         not_contains "$out" "SUDO CALLED"

echo "no Docker"
_nvidia_gpu_visible() { return 0; }
out="$(PATH="/nonexistent" provision_nvidia_container_toolkit 2>&1)"; rc=$?
assert "exits 0"                    [ "$rc" -eq 0 ]
assert "warns about missing Docker" contains "$out" "Docker not found"

echo "setup-wsl.sh wiring"
script="$(cat "$ROOT/wsl/setup-wsl.sh")"
assert "SKIP_NVIDIA defaults to true (opt-in)" contains "$script" "SKIP_NVIDIA=true"
assert "--with-nvidia flag exists"             contains "$script" "--with-nvidia)          SKIP_NVIDIA=false"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
