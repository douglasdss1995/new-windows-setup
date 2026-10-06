#!/usr/bin/env bash
# shellcheck disable=SC2088  # "~" appears literally in test descriptions, never as a path
# Tests for wsl/lib/git_config.sh: the per-machine ~/.gitconfig that includes the
# tracked shared file. The point of the whole design is the last assertion in
# each scenario: `git config --global` must never modify the tracked file.
# (Plain `git config --get` is used to read inherited values: --global/--file
# lookups do not follow [include] by default, the all-scopes lookup does.)
set -uo pipefail

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "SKIP: needs Linux/WSL (git.exe cannot read MSYS-style paths inside config files); CI runs it on ubuntu"
    exit 0 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/wsl/lib/logging.sh"
source "$ROOT/wsl/lib/git_config.sh"

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
equals() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
unchanged() { cmp -s "$REPO_PATH/git/.gitconfig" "$SHARED_ORIG"; }

REAL_HOME="$HOME"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"; HOME="$REAL_HOME"' EXIT
export GIT_CONFIG_NOSYSTEM=1
unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL

SHARED_ORIG="$TMP_ROOT/shared.orig"
cp "$ROOT/git/.gitconfig" "$SHARED_ORIG"

new_machine() { # fresh HOME + a private copy of the repo's shared file
  HOME="$(mktemp -d -p "$TMP_ROOT")"; export HOME
  REPO_PATH="$(mktemp -d -p "$TMP_ROOT")"
  mkdir -p "$REPO_PATH/git"
  cp "$SHARED_ORIG" "$REPO_PATH/git/.gitconfig"
  GIT_USERNAME="" GIT_EMAIL=""
  # Pretend the Windows GCM exists (path with a space, like Program Files).
  FAKE_GCM="$TMP_ROOT/Program Files/Git/ucrt64/bin/git-credential-manager.exe"
  mkdir -p "$(dirname "$FAKE_GCM")"; : > "$FAKE_GCM"
  _git_config_resolve_gcm() { echo "$FAKE_GCM"; }
}
quiet() { "$@" >/dev/null 2>&1; }

echo "fresh machine"
new_machine
GIT_USERNAME="Ada Lovelace" GIT_EMAIL="ada@example.com"
quiet provision_git_config
assert "~/.gitconfig is a real file, not a symlink"     [ -f "$HOME/.gitconfig" ]
assert "~/.gitconfig is not a symlink"                  [ ! -L "$HOME/.gitconfig" ]
assert "first line is the [include] of the shared file" equals "$(head -n1 "$HOME/.gitconfig")" "[include]"
assert "shared defaults are inherited (pull.rebase)"    equals "$(git config --get pull.rebase)" "true"
assert "identity written to the local file"             equals "$(git config --file "$HOME/.gitconfig" --get user.email)" "ada@example.com"
assert "credential.helper escapes the space"            equals "$(git config --file "$HOME/.gitconfig" --get credential.helper)" "${FAKE_GCM// /\\ }"
git config --global user.name "Someone Else"
git config --global credential.helper store
git config --global core.editor vim
assert "git config --global does NOT modify the tracked file" unchanged
assert "a local override wins over the shared default"  equals "$(git config --get core.editor)" "vim"

echo "re-running is idempotent and never clobbers identity"
GIT_USERNAME="Ada Lovelace" GIT_EMAIL="changed@example.com"
quiet provision_git_config
assert "include appears exactly once"                   equals "$(grep -c '^\[include\]' "$HOME/.gitconfig")" "1"
assert "existing identity is kept"                      equals "$(git config --file "$HOME/.gitconfig" --get user.email)" "ada@example.com"
assert "a custom credential.helper (store) is kept"     equals "$(git config --file "$HOME/.gitconfig" --get credential.helper)" "store"
assert "tracked file still untouched"                   unchanged

echo "stale /mnt credential.helper is replaced"
new_machine
git config --file "$HOME/.gitconfig" credential.helper "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe"
quiet provision_git_config
assert "stale mingw64 helper replaced by the resolved path" equals "$(git config --file "$HOME/.gitconfig" --get credential.helper)" "${FAKE_GCM// /\\ }"

echo "existing real ~/.gitconfig is preserved and the include goes first"
new_machine
printf '[core]\n\teditor = nano\n[pull]\n\trebase = false\n' > "$HOME/.gitconfig"
quiet provision_git_config
assert "backup of the previous file was made"           [ -f "$HOME/.gitconfig.pre-include.bak" ]
assert "include is the first line"                      equals "$(head -n1 "$HOME/.gitconfig")" "[include]"
assert "previous local settings override the shared"    equals "$(git config --get pull.rebase)" "false"
assert "previous local settings still present"          equals "$(git config --get core.editor)" "nano"
assert "shared-only settings are inherited"             equals "$(git config --get init.defaultBranch)" "main"
assert "tracked file untouched"                         unchanged

echo "identity from the old ~/.gitconfig.local is migrated"
new_machine
printf '[user]\n\tname = Old Name\n\temail = old@example.com\n' > "$HOME/.gitconfig.local"
quiet provision_git_config
assert "name migrated"                                  equals "$(git config --file "$HOME/.gitconfig" --get user.name)" "Old Name"
assert "email migrated"                                 equals "$(git config --file "$HOME/.gitconfig" --get user.email)" "old@example.com"

echo "legacy symlink (old model) is replaced by a real file"
new_machine
printf '\n[user]\n\tname = Legacy\n\temail = legacy@example.com\n' >> "$REPO_PATH/git/.gitconfig"
cp "$REPO_PATH/git/.gitconfig" "$SHARED_ORIG.legacy"
ln -s "$REPO_PATH/git/.gitconfig" "$HOME/.gitconfig"
quiet provision_git_config
assert "~/.gitconfig is no longer a symlink"            [ ! -L "$HOME/.gitconfig" ]
assert "identity found in the old target is carried over" equals "$(git config --file "$HOME/.gitconfig" --get user.email)" "legacy@example.com"
git config --global user.email "after@example.com"
assert "later --global writes do not reach the repo file" cmp -s "$REPO_PATH/git/.gitconfig" "$SHARED_ORIG.legacy"

echo "no repo path (standalone run) never writes through a legacy symlink"
new_machine
cp "$REPO_PATH/git/.gitconfig" "$SHARED_ORIG.standalone"
ln -s "$REPO_PATH/git/.gitconfig" "$HOME/.gitconfig"
REPO_PATH="" quiet provision_git_config
assert "symlink replaced"                               [ ! -L "$HOME/.gitconfig" ]
assert "standalone defaults written locally"            equals "$(git config --file "$HOME/.gitconfig" --get pull.rebase)" "true"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
