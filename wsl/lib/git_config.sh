#!/usr/bin/env bash
# git_config.sh — Git global configuration and credentials setup

# Resolve the Windows Git Credential Manager executable dynamically instead
# of hardcoding its folder. Git for Windows has changed MinGW toolchain
# subfolder (mingw64 -> ucrt64) at least once, and each time it did, the
# previously hardcoded path here silently broke credential.helper (git
# falls back to another helper if one is configured, or starts prompting
# for a password, with no obvious error pointing at this file).
_git_config_resolve_gcm() {
  find "/mnt/c/Program Files/Git" -maxdepth 3 -iname 'git-credential-manager.exe' 2>/dev/null | head -n1
}

provision_git_config() {
  step "Configuring Git"

  if [ -n "$REPO_PATH" ] && [ -f "$REPO_PATH/git/.gitconfig" ]; then
    if [ -L "$HOME/.gitconfig" ] && [ "$(readlink -f "$HOME/.gitconfig")" = "$(readlink -f "$REPO_PATH/git/.gitconfig")" ]; then
      # shellcheck disable=SC2088  # literal ~ in a message, not a path
      info "~/.gitconfig already symlinked to repo .gitconfig"
    else
      if [ -e "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
        mv "$HOME/.gitconfig" "$HOME/.gitconfig.bak"
        # shellcheck disable=SC2088  # literal ~ in a message, not a path
        warn "Existing ~/.gitconfig backed up to ~/.gitconfig.bak"
      fi
      ln -sf "$REPO_PATH/git/.gitconfig" "$HOME/.gitconfig"
      # shellcheck disable=SC2088  # literal ~ in a message, not a path
      success "~/.gitconfig -> $REPO_PATH/git/.gitconfig"
    fi

    [ -n "$GIT_USERNAME" ] && git config --file "$HOME/.gitconfig.local" user.name "$GIT_USERNAME"
    [ -n "$GIT_EMAIL" ]    && git config --file "$HOME/.gitconfig.local" user.email "$GIT_EMAIL"

    local GCM_PATH
    GCM_PATH="$(_git_config_resolve_gcm)"
    if [ -n "$GCM_PATH" ]; then
      # credential.helper runs through a shell when its value contains a
      # space, so the space in "Program Files" must be escaped or the shell
      # splits it into separate words and the helper is never found.
      git config --file "$HOME/.gitconfig.local" credential.helper "${GCM_PATH// /\\ }"
      info "Git Credential Manager (Windows) configured: $GCM_PATH"
    else
      warn "git-credential-manager.exe not found under /mnt/c/Program Files/Git - credential helper not configured"
    fi

    success "Git configured (shared .gitconfig)"
  else
    warn "Shared .gitconfig not found - applying defaults inline (pass --repo-path to use the repo's .gitconfig)"

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

    [ -n "$GIT_USERNAME" ] && git config --global user.name "$GIT_USERNAME"
    [ -n "$GIT_EMAIL" ]    && git config --global user.email "$GIT_EMAIL"

    local GCM_PATH
    GCM_PATH="$(_git_config_resolve_gcm)"
    if [ -n "$GCM_PATH" ]; then
      # credential.helper runs through a shell when its value contains a
      # space, so the space in "Program Files" must be escaped or the shell
      # splits it into separate words and the helper is never found.
      git config --global credential.helper "${GCM_PATH// /\\ }"
      info "Git Credential Manager (Windows) configured: $GCM_PATH"
    else
      warn "git-credential-manager.exe not found under /mnt/c/Program Files/Git - credential helper not configured"
    fi

    success "Git configured"
  fi
}
