# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Automation for setting up a Windows development machine from scratch, targeting Django (Python) and Angular (TypeScript) workflows. Two independent halves:

- **Windows side** (`setup-windows.ps1`, `windows/windows.config.psd1`) — installs tools on Windows via winget/Chocolatey
- **WSL side** (`wsl/setup-wsl.sh`, `setup-wsl.ps1`) — provisions the Debian dev environment inside WSL 2, run from the repo root

There are no build steps, no tests, and no linting pipeline. These are standalone scripts run manually.

## Running the Scripts

**Windows tools install** (PowerShell as Administrator):
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

**WSL setup** (PowerShell 7.6+ as Administrator, from repo root):
```powershell
.\setup-wsl.ps1                        # full setup
.\setup-wsl.ps1 -Distro Debian         # explicit distro (also the default)
.\setup-wsl.ps1 -SkipProvision:$true   # skip setup-wsl.sh
```

**WSL provisioning** (inside Debian):
```bash
bash wsl/setup-wsl.sh                  # everything
bash wsl/setup-wsl.sh --skip-docker    # without Docker
bash wsl/setup-wsl.sh --skip-python    # without Python
bash wsl/setup-wsl.sh --skip-node      # without Node
```

**Batch repo clone** (PowerShell, reads `git/git-repos.config.psd1`):
```powershell
.\git-clone.ps1
```

## Architecture

### Configuration-driven flags

All tool installs are controlled by `windows/windows.config.psd1` (Windows) — a PowerShell data file (`@{ Key = $true/$false }`) loaded with `Import-PowerShellDataFile`. `git/git-repos.config.psd1` uses the same format for repository credentials and clone targets.

### Pending refactor (`REFACTORING_PLAN.md`)

`setup-windows.ps1` is a ~580-line monolith scheduled for a SOLID refactor into:

```
modules/
├── Logger.ps1       # Write-Step/OK/Skip/Warn/Fail/Info
├── Stats.ps1        # $global:StatsInstalled/Skipped/Failed counters
├── Bootstrap.ps1    # Assert-IsAdministrator, Set-SafeExecutionPolicy, Import-SetupConfig
├── Installer.ps1    # Install-WingetPackage, Install-ChocoPackage, Install-JetBrainsIde,
│                    # Install-VsCodeExtension, Install-RemoteScript, Add-ProfileLine
└── steps/
    └── Install-*.ps1  # one file per tool category
```

The plan uses dot-sourcing (`. `) rather than `Import-Module` so all functions share one scope. Counters use `$global:` because `$script:` scope is per-file with dot-sourcing, not shared. `$SetupRoot = $PSScriptRoot` must be captured in `setup-windows.ps1` before any dot-sourcing because `$PSScriptRoot` inside a sourced file resolves to that file's directory, not the repo root.

Any new tool category should be added as a new `modules/steps/Install-<Category>.ps1` file — `setup-windows.ps1` should not need to change.

### Provisioning output must never go silent

`wsl/lib/*.sh` steps run non-interactively from PowerShell (`setup-wsl.ps1` shells out via `wsl -d $Distro -- bash -c ...`), so there's no other signal to the user that anything is happening besides stdout. A step that produces no output for more than a few seconds is indistinguishable from a hang, and the fully-silent `apt-get ... -qq` on `build-essential`/`llvm` (in `wsl/lib/system.sh`) has already been mistaken for a frozen script once.

- Never use `apt-get -qq` for an install that can take more than a few seconds — use `-q` instead, which still suppresses noise but prints each package name as it downloads/unpacks, so output keeps moving.
- Never pipe a large download through fully-silent curl (`-s`) with no surrounding message — either drop `-s` (keep `-f`/`-S` so curl's own progress meter shows) or print an `info "Downloading X (~N MB) - this can take a few minutes..."` line first (see `provision_gitkraken` in `wsl/lib/gitkraken.sh` for the pattern).
- When adding a new step to `wsl/lib/`, ask: if this takes 3+ minutes on a slow connection, will the user see *something* move in that window? If not, add a heads-up `info`/progress line before it runs.

`apt-get` can also exit 0 while having installed nothing — an interrupted run (Ctrl+C) or one unresolvable package name aborting the whole transaction (the `software-properties-common` incident) doesn't reliably surface as a failing exit code, so `run_step`'s `set -e` guard doesn't catch it either, and the step logs `[OK]` while later steps hit `command not found`. Any step whose downstream steps hard-depend on a binary it installs (see `provision_base_deps` in `wsl/lib/system.sh`) should verify with `command -v` after the install and `return 1` if something critical is missing, rather than trusting apt's exit code alone.

### WSL providers

`wsl/providers/docker-compose.yml` runs PostgreSQL, Redis, pgAdmin, and Portainer. `setup-wsl.sh` copies this to `~/providers/` inside WSL and registers a systemd service for auto-start. Credentials live in `~/providers/.env` (not committed; see `.env.example`).

### WSL startup timer

The `setup-wsl.sh` provisioning script automatically adds a startup timer to both `.zshrc` (default shell) and `.bashrc`. When you open WSL from Windows Terminal (e.g. `wsl` command), you'll see:

```
⏱️  WSL iniciado em 3s
```

This is implemented via the built-in `$SECONDS` variable in bash/zsh, which counts seconds since shell initialization. The timer is added during the `provision_zshrc_config()` step in `wsl/lib/zsh.sh` and only displays once per session (guarded by `WSL_STARTUP_LOGGED` environment variable).
