# git/.gitconfig

Shared Git configuration, tracked at `git/.gitconfig` and symlinked to `$HOME/.gitconfig` on **both** Windows (by `setup-windows.ps1`) and WSL (by `setup-wsl.sh`, via `install-wsl.ps1` passing `--repo-path`). Editing this one file changes Git behavior identically in both environments — no need to update two config blocks.

It only holds shared defaults (delta as pager, linear-history rebase workflow, merge/diff behavior, aliases) — **never** personal identity. `user.name`/`user.email` are written to a separate, untracked `~/.gitconfig.local`, which `.gitconfig` includes automatically. That file is populated from `windows/windows.config.psd1`'s `Git` block (see the main [README Configuration section](../README.md#configuration)), so filling in your identity once applies it on both OSes.

If `~/.gitconfig` already exists as a regular file when the scripts run, it's backed up to `~/.gitconfig.bak` before the symlink is created.

It lives in `git/` alongside `git-repos.config.psd1` rather than at the repo root — both are git-related config that other scripts locate by path (`git/.gitconfig`, `git/git-repos.config.psd1`).

Running `setup-wsl.sh` standalone (without `install-wsl.ps1`, e.g. `bash setup-wsl.sh` inside an already-provisioned WSL) falls back to applying the same settings inline via `git config --global`, since there's no repo path to symlink to in that case.
