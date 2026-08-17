# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Automation for setting up a Windows development machine from scratch, targeting Django (Python) and Angular (TypeScript) workflows. Two independent halves:

- **Windows side** (`setup-windows.ps1`, `windows/windows.config.psd1`) — installs tools on Windows via winget/Chocolatey
- **WSL side** (`setup-wsl.sh`, `install-wsl.ps1`) — provisions the Debian dev environment inside WSL 2, run from the repo root

There are no build steps, no tests, and no linting pipeline. These are standalone scripts run manually.

## Running the Scripts

**Windows tools install** (PowerShell as Administrator):
```powershell
powershell -ExecutionPolicy Bypass -File setup-windows.ps1
```

**WSL setup** (PowerShell 7.6+ as Administrator, from repo root):
```powershell
.\install-wsl.ps1                        # full setup
.\install-wsl.ps1 -Distro Debian         # explicit distro (also the default)
.\install-wsl.ps1 -SkipProvision:$true   # skip setup-wsl.sh
```

**WSL provisioning** (inside Debian):
```bash
bash setup-wsl.sh                  # everything
bash setup-wsl.sh --skip-docker    # without Docker
bash setup-wsl.sh --skip-python    # without Python
bash setup-wsl.sh --skip-node      # without Node
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

### WSL providers

`wsl/providers/docker-compose.yml` runs PostgreSQL, Redis, pgAdmin, and Portainer. `setup-wsl.sh` copies this to `~/providers/` inside WSL and registers a systemd service for auto-start. Credentials live in `~/providers/.env` (not committed; see `.env.example`).

### WSL startup timer

The `setup-wsl.sh` provisioning script automatically adds a startup timer to both `.zshrc` (default shell) and `.bashrc`. When you open WSL from Windows Terminal (e.g. `wsl` command), you'll see:

```
⏱️  WSL iniciado em 3s
```

This is implemented via the built-in `$SECONDS` variable in bash/zsh, which counts seconds since shell initialization. The timer is added during the `provision_zshrc_config()` step in `wsl/lib/zsh.sh` and only displays once per session (guarded by `WSL_STARTUP_LOGGED` environment variable).
