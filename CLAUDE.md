# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Automation for setting up a Windows development machine from scratch, targeting Django (Python) and Angular (TypeScript) workflows. Two independent halves:

- **Windows side** (`windows.ps1`, `windows.config.psd1`) — installs tools on Windows via winget/Chocolatey
- **WSL side** (`wsl/provision.sh`, `wsl/setup-wsl.ps1`) — provisions the Ubuntu dev environment inside WSL 2

There are no build steps, no tests, and no linting pipeline. These are standalone scripts run manually.

## Running the Scripts

**Windows tools install** (PowerShell as Administrator):
```powershell
powershell -ExecutionPolicy Bypass -File windows.ps1
```

**WSL setup** (PowerShell 7.6+ as Administrator):
```powershell
cd wsl
.\setup-wsl.ps1                        # full setup
.\setup-wsl.ps1 -Distro Ubuntu-22.04   # different distro
.\setup-wsl.ps1 -SkipProvision:$true   # skip provision.sh
```

**WSL provisioning** (inside Ubuntu):
```bash
bash provision.sh                  # everything
bash provision.sh --skip-docker    # without Docker
bash provision.sh --skip-python    # without Python
bash provision.sh --skip-node      # without Node
```

**Batch repo clone** (PowerShell):
```powershell
.\git-clone.ps1
```

## Architecture

### Configuration-driven flags

All tool installs are controlled by `windows.config.psd1` (Windows) — a PowerShell data file (`@{ Key = $true/$false }`) loaded with `Import-PowerShellDataFile`. `git-repos.config.psd1` uses the same format for repository credentials and clone targets.

### Pending refactor (`REFACTORING_PLAN.md`)

`windows.ps1` is a ~580-line monolith scheduled for a SOLID refactor into:

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

The plan uses dot-sourcing (`. `) rather than `Import-Module` so all functions share one scope. Counters use `$global:` because `$script:` scope is per-file with dot-sourcing, not shared. `$SetupRoot = $PSScriptRoot` must be captured in `windows.ps1` before any dot-sourcing because `$PSScriptRoot` inside a sourced file resolves to that file's directory, not the repo root.

Any new tool category should be added as a new `modules/steps/Install-<Category>.ps1` file — `windows.ps1` should not need to change.

### WSL providers

`wsl/providers/docker-compose.yml` runs PostgreSQL, Redis, pgAdmin, and Portainer. `provision.sh` copies this to `~/providers/` inside WSL and registers a systemd service for auto-start. Credentials live in `~/providers/.env` (not committed; see `.env.example`).
