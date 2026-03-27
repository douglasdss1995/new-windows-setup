# new-windows-setup

Automation for setting up a Windows development machine from scratch, focused on **Django** (Python) and **Angular** (TypeScript) projects, with support for multiple languages and tools.

---

## Overview

```
new-windows-setup/
├── ferramentas.md              # Complete catalog of recommended tools
├── windows.ps1                 # Installs all tools on Windows via winget/choco
├── windows.config.psd1         # Configuration file (enable/disable tools)
└── wsl/
    ├── setup-wsl.ps1           # Enables and configures WSL 2 + Ubuntu
    ├── .wslconfig              # Global WSL configuration (memory, CPU, network)
    ├── wsl.conf                # Internal distro Linux configuration
    ├── provision.sh            # Provisions the dev environment inside Ubuntu
    └── providers/              # Shared services compose reference
        ├── docker-compose.yml
        ├── .env.example
        └── providers/
            ├── postgres/init/01-init-db.sql
            ├── redis/redis.conf
            └── pgadmin/servers.json
```

---

## Prerequisites

- Windows 10 (21H2+) or Windows 11
- PowerShell running as **Administrator**
  - `windows.ps1` — Windows PowerShell 5.1 or PowerShell 7
  - `setup-wsl.ps1` — **PowerShell 7.6** or later (required)
- Internet connection

---

## Execution Policy

By default Windows blocks `.ps1` script execution. If you see this error:

```
.\windows.ps1 cannot be loaded because running scripts is disabled on this system.
```

Choose **one** of the options below:

### Option A — Current session only (safer, no permanent effect)
```powershell
powershell -ExecutionPolicy Bypass -File .\windows.ps1
```
> Use this if you don't want to change the machine policy.

### Option B — Current user only (recommended for devs, permanent)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
> No Admin required. Local scripts run freely; downloaded scripts need a digital signature. **Recommended.**

### Option C — Entire machine (requires Admin)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```
> Applies to all users on the machine.

### Check current policy
```powershell
Get-ExecutionPolicy -List
```

| Policy | Description |
|---|---|
| `Restricted` | No scripts can run (Windows default) |
| `AllSigned` | Only digitally signed scripts |
| `RemoteSigned` | Local scripts free; downloaded need signature |
| `Bypass` | Everything runs without restriction |
| `Unrestricted` | Everything runs, but shows warning for downloaded scripts |

> **Note:** `windows.ps1` automatically detects `Restricted` or `AllSigned` policy and adjusts to `RemoteSigned` at `CurrentUser` scope before continuing — but it needs to be called first with **Option A** or via PowerShell as Admin.

---

## Quick Start

### Step 1 — Install Windows tools

```powershell
# PowerShell as Administrator
.\windows.ps1
```

At the end of execution the script displays:

```
Next steps:
  1. Restart the computer to apply PATH changes
  2. Authenticate with GitHub:
       gh auth login
  3. Configure WSL:
       cd wsl
       .\setup-wsl.ps1
```

### Step 2 — Configure WSL

> **Requires PowerShell 7.6.** Open PowerShell 7 as Administrator before running this step.

```powershell
# PowerShell 7.6 as Administrator
cd wsl
.\setup-wsl.ps1
```

**If Ubuntu is not yet installed**, the script installs the distro and pauses:

```
[WARN] First run requires creating a user. Launch it manually once before continuing.

  Run: wsl -d ubuntu
  Create your user and password, then run this script again.
```

Open a new terminal, run `wsl -d ubuntu`, enter a username and password when prompted, then exit WSL and run `.\setup-wsl.ps1` again to complete the setup.

On the second run, the script applies the configuration and automatically runs `provision.sh` inside WSL.

### Step 3 — Final configuration

```bash
# Inside WSL
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
gh auth login
```

---

## windows.ps1

Installs all tools listed in `ferramentas.md` using **winget** (primary) and **Chocolatey** (complement).

| Category | Examples |
|---|---|
| Terminal | Windows Terminal, PowerShell 7, Git Bash, Oh My Posh, Starship |
| Editors | VS Code, Cursor, PyCharm Community, WebStorm |
| Runtimes | mise, pyenv-win, nvm, Python, Node LTS, JDK 21, uv, pnpm |
| Databases | PostgreSQL, DBeaver, TablePlus, pgAdmin, Redis Insight |
| Docker | Docker Engine in WSL (via `provision.sh`) + providers compose |
| API | Postman, Insomnia, Bruno |
| CLI | ripgrep, fd, bat, eza, fzf, zoxide, jq, delta, just |
| Security | Bitwarden, Gpg4win, OpenSSH |
| Productivity | PowerToys, Obsidian, ShareX, Everything, AutoHotkey |
| Browsers | Chrome, Firefox Developer Edition |
| Fonts | JetBrains Mono Nerd, Fira Code, Cascadia Code |
| VS Code | 17 extensions for Python/Django, Angular/TS and general utilities |

---

## setup-wsl.ps1

> **Requires PowerShell 7.6** as Administrator.

Orchestrates the complete WSL 2 installation and configuration.

**What it does:**
1. Enables `WSL` and `VirtualMachinePlatform` Windows features
2. Updates the WSL kernel
3. Sets WSL 2 as default
4. Installs the distro (default: Ubuntu 24.04)
5. Copies `.wslconfig` to `%USERPROFILE%`
6. Injects `wsl.conf` into `/etc/wsl.conf` inside the distro
7. Restarts WSL to apply configuration
8. Runs `provision.sh` automatically

```powershell
# Full installation (default)
.\setup-wsl.ps1

# Use a different distro
.\setup-wsl.ps1 -Distro Ubuntu-22.04

# Configure WSL without provisioning
.\setup-wsl.ps1 -SkipProvision:$true
```

---

## provision.sh

Provisions the development environment inside Ubuntu.

**What it installs:**

| Step | Content |
|---|---|
| System | Build dependencies, curl, wget, make |
| Shell | Zsh, Oh My Zsh, plugins (autosuggestions, syntax-highlighting, completions) |
| mise | Universal runtime manager |
| Python | Latest version via mise + uv + poetry, black, ruff, mypy, pytest, ipython |
| Node.js | LTS via mise + pnpm + Angular CLI, ESLint, Prettier |
| CLI | ripgrep, fd, bat, eza, fzf, zoxide, delta, jq, yq, gh |
| Docker | Native daemon (no Docker Desktop) + systemd enable (auto-start) |
| Providers | PostgreSQL, Redis, pgAdmin, Portainer via compose at `~/providers/` |
| Git | Configured with delta as pager |
| Shell config | `.zshrc` with aliases for Django, Git, Docker, Python, Providers (`pvup`, `pvdown`...) |

**Flags:**

```bash
bash provision.sh                  # everything
bash provision.sh --skip-docker    # without Docker
bash provision.sh --skip-python    # without Python
bash provision.sh --skip-node      # without Node
```

---

## .wslconfig

Global WSL configuration, copied to `%USERPROFILE%\.wslconfig`.

Optimized for **32 GB RAM / 16 cores**. Adjust for your machine:

```ini
[wsl2]
memory=16GB        # 50% of total RAM recommended
processors=8       # half of logical cores
swap=4GB
networkingMode=mirrored   # shared localhost Windows <-> WSL
autoMemoryReclaim=gradual # returns RAM to Windows when idle
```

---

## wsl.conf

Internal distro configuration, applied at `/etc/wsl.conf`.

Highlights:
- `systemd=true` — required for native Docker and services
- Windows drive mounting with correct permissions (`metadata,uid=1000`)
- `hostname=dev-wsl`
- `appendWindowsPath=true` — allows using `code .` and other Windows binaries in WSL terminal

---

## Providers

`provision.sh` automatically configures shared services at `~/providers/` inside WSL and creates a systemd service to start them automatically.

| Service | URL / Port | Default credentials |
|---|---|---|
| PostgreSQL | `localhost:5432` | `postgres` / `postgres` |
| Redis | `localhost:6379` | — |
| pgAdmin | http://localhost:5050 | `admin@admin.com` / `admin` |
| Portainer | http://localhost:9000 | (set on first access) |

**Shell aliases available after provisioning:**

```bash
pvup        # docker compose up -d
pvdown      # docker compose down
pvlogs      # docker compose logs -f
pvps        # docker compose ps
pvrestart   # docker compose restart
```

> Edit default passwords at `~/providers/.env` before starting services.

---

## Tools

See [`ferramentas.md`](./ferramentas.md) for the complete catalog with links and descriptions of all recommended tools.

---

## License

[MIT](./LICENSE)
