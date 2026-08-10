#!/usr/bin/env bash
# git_config.sh — Git global configuration and credentials setup

provision_git_config() {
  step "Configuring Git"

  if [ -n "$REPO_PATH" ] && [ -f "$REPO_PATH/git/.gitconfig" ]; then
    if [ -L "$HOME/.gitconfig" ] && [ "$(readlink -f "$HOME/.gitconfig")" = "$(readlink -f "$REPO_PATH/git/.gitconfig")" ]; then
      info "~/.gitconfig already symlinked to repo .gitconfig"
    else
      if [ -e "$HOME/.gitconfig" ] && [ ! -L "$HOME/.gitconfig" ]; then
        mv "$HOME/.gitconfig" "$HOME/.gitconfig.bak"
        warn "Existing ~/.gitconfig backed up to ~/.gitconfig.bak"
      fi
      ln -sf "$REPO_PATH/git/.gitconfig" "$HOME/.gitconfig"
      success "~/.gitconfig -> $REPO_PATH/git/.gitconfig"
    fi

    [ -n "$GIT_USERNAME" ] && git config --file "$HOME/.gitconfig.local" user.name "$GIT_USERNAME"
    [ -n "$GIT_EMAIL" ]    && git config --file "$HOME/.gitconfig.local" user.email "$GIT_EMAIL"

    local GCM_PATH="/mnt/c/Program Files/Git/mingw64/libexec/git-core/git-credential-manager.exe"
    if [ -f "$GCM_PATH" ]; then
      git config --file "$HOME/.gitconfig.local" credential.helper "$GCM_PATH"
      info "Git Credential Manager (Windows) configured"
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

    local GCM_PATH="/mnt/c/Program Files/Git/mingw64/libexec/git-core/git-credential-manager.exe"
    if [ -f "$GCM_PATH" ]; then
      git config --global credential.helper "$GCM_PATH"
      info "Git Credential Manager (Windows) configured"
    fi

    success "Git configured"
  fi
}
