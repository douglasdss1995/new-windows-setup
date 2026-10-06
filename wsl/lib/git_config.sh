#!/usr/bin/env bash
# shellcheck disable=SC2088  # "~" appears literally in user-facing messages, never as a path
# git_config.sh — Git global configuration and credentials setup
#
# Model: ~/.gitconfig is a REAL, untracked, per-machine file whose first lines
# [include] the shared defaults tracked in the repo (git/.gitconfig). It used
# to be a symlink to that tracked file, which made every `git config --global`
# (typed by hand, run by an IDE, a Claude session, a stale setup copy...) write
# straight into the repository. With the include, --global writes land in the
# local file and the tracked one stays read-only in practice.

# Resolve the Windows Git Credential Manager executable dynamically instead
# of hardcoding its folder. Git for Windows has changed MinGW toolchain
# subfolder (mingw64 -> ucrt64) at least once, and each time it did, the
# previously hardcoded path here silently broke credential.helper (git
# falls back to another helper if one is configured, or starts prompting
# for a password, with no obvious error pointing at this file).
_git_config_resolve_gcm() {
  find "/mnt/c/Program Files/Git" -maxdepth 3 -iname 'git-credential-manager.exe' 2>/dev/null | head -n1
}

# Set <key> in <file> only when it has no value yet, so re-running the setup
# never clobbers an identity the user already chose.
_git_config_set_if_unset() { # <file> <key> <value>
  local file="$1" key="$2" value="$3"
  [ -n "$value" ] || return 0
  if [ -n "$(git config --file "$file" --get "$key" 2>/dev/null)" ]; then
    info "git $key already set in ${file/#$HOME/\~} - kept"
  else
    git config --file "$file" "$key" "$value"
    success "git $key set in ${file/#$HOME/\~}"
  fi
}

# Point credential.helper at the Windows GCM. Only writes when the key is unset
# or holds a stale /mnt/c path (e.g. the old mingw64 one); custom helpers such
# as `store` or `cache` are left alone.
_git_config_set_gcm() { # <file>
  local file="$1" gcm current
  gcm="$(_git_config_resolve_gcm)"
  if [ -z "$gcm" ]; then
    warn "git-credential-manager.exe not found under /mnt/c/Program Files/Git - credential helper not configured"
    return 0
  fi
  current="$(git config --file "$file" --get credential.helper 2>/dev/null)"
  # credential.helper runs through a shell when its value contains a space, so
  # the space in "Program Files" must be escaped or the shell splits it into
  # separate words and the helper is never found.
  if [ -z "$current" ] || { [[ "$current" == /mnt/* ]] && [ ! -e "${current//\\ / }" ]; }; then
    git config --file "$file" credential.helper "${gcm// /\\ }"
    info "Git Credential Manager (Windows) configured: $gcm"
  else
    info "credential.helper already set - kept"
  fi
}

# Turn a legacy ~/.gitconfig symlink (old model) into a regular file, carrying
# over the identity that may have been written into the tracked target.
# Echoes nothing; leaves $HOME/.gitconfig as a real (possibly empty) file.
_git_config_desymlink() {
  local cfg="$HOME/.gitconfig" target name email
  [ -L "$cfg" ] || return 0
  target="$(readlink -f "$cfg")"
  name="$(git config --file "$target" --get user.name 2>/dev/null)"
  email="$(git config --file "$target" --get user.email 2>/dev/null)"
  rm "$cfg"
  : > "$cfg"
  [ -n "$name" ]  && git config --file "$cfg" user.name "$name"
  [ -n "$email" ] && git config --file "$cfg" user.email "$email"
  warn "~/.gitconfig was a symlink to the repo - replaced by a local file (writes no longer reach the repo)"
}

# Guarantee ~/.gitconfig is a real file whose FIRST section includes the shared
# defaults (first, so anything defined locally afterwards wins).
_git_config_link_shared() { # <shared .gitconfig path>
  local shared="$1" cfg="$HOME/.gitconfig" tmp

  _git_config_desymlink

  if [ ! -e "$cfg" ]; then
    printf '[include]\n\tpath = %s\n' "$shared" > "$cfg"
    success "~/.gitconfig created (includes $shared)"
    return 0
  fi

  if git config --file "$cfg" --get-all include.path 2>/dev/null | grep -qxF "$shared"; then
    info "~/.gitconfig already includes the shared .gitconfig"
    return 0
  fi

  [ -e "$HOME/.gitconfig.pre-include.bak" ] || cp "$cfg" "$HOME/.gitconfig.pre-include.bak"
  tmp="$(mktemp)"
  { printf '[include]\n\tpath = %s\n' "$shared"; cat "$cfg"; } > "$tmp"
  cat "$tmp" > "$cfg"
  rm -f "$tmp"
  success "~/.gitconfig now includes the shared .gitconfig (backup: ~/.gitconfig.pre-include.bak)"
}

provision_git_config() {
  step "Configuring Git"

  if [ -n "$REPO_PATH" ] && [ -f "$REPO_PATH/git/.gitconfig" ]; then
    local shared
    shared="$(readlink -f "$REPO_PATH/git/.gitconfig")"
    _git_config_link_shared "$shared"

    # Identity from the pre-include design lived in ~/.gitconfig.local.
    if [ -f "$HOME/.gitconfig.local" ]; then
      local old_name old_email
      old_name="$(git config --file "$HOME/.gitconfig.local" --get user.name 2>/dev/null)"
      old_email="$(git config --file "$HOME/.gitconfig.local" --get user.email 2>/dev/null)"
      _git_config_set_if_unset "$HOME/.gitconfig" user.name  "$old_name"
      _git_config_set_if_unset "$HOME/.gitconfig" user.email "$old_email"
    fi

    _git_config_set_if_unset "$HOME/.gitconfig" user.name  "$GIT_USERNAME"
    _git_config_set_if_unset "$HOME/.gitconfig" user.email "$GIT_EMAIL"
    _git_config_set_gcm "$HOME/.gitconfig"

    success "Git configured (local ~/.gitconfig + shared defaults from the repo)"
  else
    warn "Shared .gitconfig not found - applying defaults inline (pass --repo-path to use the repo's .gitconfig)"

    # Never let the inline --global writes below reach a repo file through a
    # legacy symlink.
    _git_config_desymlink

    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.light false
    git config --global delta.line-numbers true
    git config --global delta.side-by-side false
    git config --global merge.conflictstyle diff3
    git config --global merge.ff only
    git config --global diff.colorMoved default
    git config --global pull.rebase true
    git config --global rebase.autoStash true
    git config --global push.default current
    git config --global push.autoSetupRemote true
    git config --global init.defaultBranch main
    git config --global core.autocrlf input
    git config --global core.editor "code --wait"
    git config --global fetch.prune true
    git config --global rerere.enabled true
    git config --global help.autocorrect 1
    git config --global commit.verbose true
    git config --global alias.pushf "push --force-with-lease"

    _git_config_set_if_unset "$HOME/.gitconfig" user.name  "$GIT_USERNAME"
    _git_config_set_if_unset "$HOME/.gitconfig" user.email "$GIT_EMAIL"
    _git_config_set_gcm "$HOME/.gitconfig"

    success "Git configured"
  fi
}
