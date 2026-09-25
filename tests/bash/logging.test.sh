#!/usr/bin/env bash
# Tests for wsl/lib/logging.sh (run_step isolation). Plain bash: no test framework needed.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/wsl/lib/logging.sh"

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

ok_step()  { return 0; }
bad_step() { false; echo "should not reach here"; }
mid_fail() { echo before; false; echo after; }

echo "run_step"
FAILED_STEPS=()
run_step "good" ok_step
assert "a passing step is not recorded as failed" [ "${#FAILED_STEPS[@]}" -eq 0 ]

run_step "bad" bad_step >/dev/null 2>&1
assert "a failing step is recorded in FAILED_STEPS" [ "${FAILED_STEPS[*]}" = "bad" ]

run_step "next" ok_step
assert "later steps still run after a failure" [ "${#FAILED_STEPS[@]}" -eq 1 ]

out="$(run_step "mid" mid_fail 2>&1)"
assert "a step stops at its first failing command (set -e)" not_contains "$out" after

echo "logging helpers"
assert "info prefixes [INFO]"  contains "$(info hi)" "[INFO]"
assert "success prefixes [OK]" contains "$(success hi)" "[OK]"
assert "warn prefixes [WARN]"  contains "$(warn hi)" "[WARN]"

echo "syntax"
for f in "$ROOT"/wsl/setup-wsl.sh "$ROOT"/wsl/lib/*.sh; do
  assert "bash -n ${f#"$ROOT"/}" bash -n "$f"
done

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
