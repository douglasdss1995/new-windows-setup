#!/usr/bin/env bash
# Tests for guard_windows_shim_completions / verify_zsh_startup in wsl/lib/zsh.sh.
# Regression: `source <(ng completion script)` resolved to a Windows shim in
# /mnt/c and hung `wsl` before the prompt.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/wsl/lib/logging.sh"
source "$ROOT/wsl/lib/zsh.sh"

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
has_line() { grep -qxF -- "$2" "$1"; }
count_lines() { [ "$(grep -cxF -- "$2" "$1")" -eq "$3" ]; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "guard: bare ng completion line"
rc="$WORK/zshrc"
cat > "$rc" <<'EOF'
export FOO=1
# Load Angular CLI autocompletion.
source <(ng completion script)
alias gs='git status'
EOF
guard_windows_shim_completions "$rc" >/dev/null
assert "wrapped in an if guard"        has_line "$rc" 'if (( $+commands[ng] )) && [[ ${commands[ng]} != /mnt/* ]]; then'
assert "completion line kept, indented" has_line "$rc" '  source <(ng completion script)'
assert "no bare completion line left"  count_lines "$rc" 'source <(ng completion script)' 0
assert "closes with fi"                has_line "$rc" 'fi'
assert "unrelated lines untouched"     has_line "$rc" "alias gs='git status'"

echo "guard: idempotent"
cp "$rc" "$WORK/once"
guard_windows_shim_completions "$rc" >/dev/null
assert "second run changes nothing"    cmp -s "$rc" "$WORK/once"

echo "guard: other tools and missing trailing newline"
printf 'source <(kubectl completion zsh)\nsource <(gh completion -s zsh)' > "$rc"
guard_windows_shim_completions "$rc" >/dev/null
assert "kubectl guarded"               has_line "$rc" 'if (( $+commands[kubectl] )) && [[ ${commands[kubectl]} != /mnt/* ]]; then'
assert "gh guarded (last line, no newline)" has_line "$rc" 'if (( $+commands[gh] )) && [[ ${commands[gh]} != /mnt/* ]]; then'

echo "guard: leaves non-completion sources alone"
printf 'source ~/.fzf.zsh\neval "$(zoxide init zsh)"\n' > "$rc"
cp "$rc" "$WORK/same"
guard_windows_shim_completions "$rc" >/dev/null
assert "file unchanged"                cmp -s "$rc" "$WORK/same"

echo "guard: missing file is not an error"
assert "returns 0"                     guard_windows_shim_completions "$WORK/nope"

echo "verify: timeout fails, success passes"
STUBS="$WORK/bin"; mkdir -p "$STUBS"
printf '#!/bin/sh\nexit 0\n' > "$STUBS/zsh"; chmod +x "$STUBS/zsh"
# shellcheck disable=SC2329  # invoked indirectly by verify_zsh_startup
timeout() { return 124; }
PATH="$STUBS:$PATH" verify_zsh_startup >/dev/null 2>&1; rc_hang=$?
# shellcheck disable=SC2329
timeout() { return 0; }
PATH="$STUBS:$PATH" verify_zsh_startup >/dev/null 2>&1; rc_ok=$?
# shellcheck disable=SC2329
timeout() { return 3; }
PATH="$STUBS:$PATH" verify_zsh_startup >/dev/null 2>&1; rc_other=$?
unset -f timeout
assert "rc 124 (hang) fails the step"              [ "$rc_hang" -eq 1 ]
assert "rc 0 passes"                               [ "$rc_ok" -eq 0 ]
assert "other non-zero status is not a hang"       [ "$rc_other" -eq 0 ]

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
