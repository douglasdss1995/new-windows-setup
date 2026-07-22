# new-windows-setup

Automation for setting up a Windows development machine from scratch, focused on **Django** (Python) and **Angular** (TypeScript) projects, with support for multiple languages and tools.

---

## Overview

```
new-windows-setup/
├── ferramentas.md              # Complete catalog of recommended tools
├── windows.ps1                 # Installs all tools on Windows via winget/choco
├── windows.config.psd1.example # Configuration template (copy to windows.config.psd1)
├── windows.config.psd1         # Your local configuration (gitignored, created by you)
├── git-repos.config.psd1.example # Repo-clone config template (copy to git-repos.config.psd1)
├── .gitconfig                  # Shared Git config, symlinked to $HOME/.gitconfig (Windows + WSL)
├── themes/
│   └── amro.omp.json           # Oh My Posh prompt theme (default) - edit to customize
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

| Policy         | Description                                               |
| -------------- | --------------------------------------------------------- |
| `Restricted`   | No scripts can run (Windows default)                      |
| `AllSigned`    | Only digitally signed scripts                             |
| `RemoteSigned` | Local scripts free; downloaded need signature             |
| `Bypass`       | Everything runs without restriction                       |
| `Unrestricted` | Everything runs, but shows warning for downloaded scripts |

> **Note:** `windows.ps1` automatically detects `Restricted` or `AllSigned` policy and adjusts to `RemoteSigned` at `CurrentUser` scope before continuing — but it needs to be called first with **Option A** or via PowerShell as Admin.

---

## Configuration

Both config files below are **gitignored** — only the `.example` templates are versioned. Before running any script, copy each template and fill it in:

```powershell
Copy-Item windows.config.psd1.example windows.config.psd1
Copy-Item git-repos.config.psd1.example git-repos.config.psd1
```

### windows.config.psd1

Controls which tools are installed on Windows. Set each flag to `$true` (install) or `$false` (skip).

Start by filling in your Git identity. This is the **single source of truth** for your Git identity — `windows.ps1` applies it on Windows, and `setup-wsl.ps1` reads the same file and passes it through to `provision.sh` so it's applied inside WSL too (see [.gitconfig](#gitconfig)):

```powershell
Git = @{
    UserName  = "Your Name"
    UserEmail = "your@email.com"
}
```

Key sections to review before your first run:

| Section        | What to decide                                                       |
| -------------- | -------------------------------------------------------------------- |
| `Editors`      | VS Code, Cursor, JetBrains IDEs — enable only what you use           |
| `Runtimes`     | Mise is recommended; disable `PyenvWin` / `NvmWindows` if using Mise |
| `Database`     | Enable only the database tools you actually need                     |
| `Productivity` | Slack, Discord, Notion — opt-in only                                 |

### git-repos.config.psd1

Controls which repositories are cloned automatically when you run `git-clone.ps1`. Edit credentials and repo list before running that script.

**1. Set the base clone directory:**

```powershell
CloneBaseDir = "$HOME\projects"
```

**2. Configure a credential provider** (choose Token for HTTPS or SSHKey for SSH):

```powershell
Providers = @{
    GitHub = @{
        Host  = "github.com"
        Token = "ghp_yourPersonalAccessToken"
    }
    GitLab = @{
        Host   = "gitlab.mycompany.com"
        SSHKey = "$HOME\.ssh\id_rsa_gitlab"
    }
}
```

**3. Add the repositories to clone:**

```powershell
Repositories = @(
    @{ Url = "https://github.com/youruser/project-a"; Provider = "GitHub" }
    @{
        Url      = "git@gitlab.mycompany.com:group/project-b.git"
        Provider = "GitLab"
        Dir      = "project-b-custom-name"   # optional: override folder name
        Branch   = "develop"                  # optional: checkout specific branch
    }
)
```

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

### Step 3 — Clone repositories

After restarting, configure `git-repos.config.psd1` (see [Configuration](#configuration)) and run:

```powershell
# PowerShell — clones all repositories listed in git-repos.config.psd1
.\git-clone.ps1
```

### Step 4 — Final configuration

Git identity and the shared `.gitconfig` were already applied automatically in Step 2 (from `windows.config.psd1`, see [.gitconfig](#gitconfig)). All that's left:

```bash
# Inside WSL
gh auth login
```

---

## windows.ps1

Installs all tools listed in `ferramentas.md` using **winget** (primary) and **Chocolatey** (complement).

| Category     | Examples                                                          |
| ------------ | ----------------------------------------------------------------- |
| Terminal     | Windows Terminal, PowerShell 7, Git Bash, Oh My Posh, Starship    |

> Oh My Posh is enabled by default and activated automatically in your PowerShell profile using the `amro` theme (`themes/amro.omp.json`). To customize, edit that file directly, or add another `*.omp.json` file to `themes/` and point `Terminal.OhMyPoshTheme` at it in `windows.config.psd1`.
| Editors      | VS Code, Cursor, PyCharm Community, WebStorm                      |
| Runtimes     | mise, pyenv-win, nvm, Python, Node LTS, JDK 21, uv, pnpm          |
| Databases    | PostgreSQL, DBeaver, TablePlus, pgAdmin, Redis Insight            |
| Docker       | Docker Engine in WSL (via `provision.sh`) + providers compose     |
| API          | Postman, Insomnia, Bruno                                          |
| CLI          | ripgrep, fd, bat, eza, fzf, zoxide, jq, delta, just               |
| Security     | Bitwarden, Gpg4win, OpenSSH                                       |
| Productivity | PowerToys, Obsidian, ShareX, Everything, AutoHotkey               |
| Browsers     | Chrome, Firefox Developer Edition, Opera (opt-in)                 |
| Fonts        | JetBrains Mono Nerd, Fira Code, Cascadia Code                     |
| VS Code      | 18 extensions for Python/Django, Angular/TS and general utilities |

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

| Step         | Content                                                                                |
| ------------ | -------------------------------------------------------------------------------------- |
| System       | Build dependencies, curl, wget, make                                                   |
| Shell        | Zsh, Oh My Zsh, plugins (autosuggestions, syntax-highlighting, completions)            |
| mise         | Universal runtime manager                                                              |
| Python       | Latest version via mise + uv + poetry, black, ruff, mypy, pytest, ipython              |
| Node.js      | LTS via mise + pnpm + Angular CLI, ESLint, Prettier                                    |
| CLI          | ripgrep, fd, bat, eza, fzf, zoxide, delta, jq, yq, gh                                  |
| direnv       | Per-directory environment variable loading (`.envrc` files)                            |
| Docker       | Native daemon (no Docker Desktop) + systemd enable (auto-start)                        |
| Providers    | PostgreSQL, Redis, pgAdmin, Portainer via compose at `~/providers/`                    |
| Git          | Shared `.gitconfig` symlinked from the repo (see [.gitconfig](#gitconfig))             |
| Shell config | `.zshrc` with aliases for Django, Git, Docker, Python, Providers (`pvup`, `pvdown`...) |

**Flags:**

```bash
bash provision.sh                        # everything
bash provision.sh --skip-docker          # without Docker (also skips all providers)
bash provision.sh --skip-python          # without Python
bash provision.sh --skip-node            # without Node

# Individual provider flags (requires Docker)
bash provision.sh --skip-postgres        # without PostgreSQL (also skips pgAdmin)
bash provision.sh --skip-redis           # without Redis
bash provision.sh --skip-pgadmin         # without pgAdmin
bash provision.sh --skip-portainer       # without Portainer
```

Flags can be combined freely:

```bash
# Docker + only Redis (no Postgres, pgAdmin or Portainer)
bash provision.sh --skip-postgres --skip-pgadmin --skip-portainer

# Everything except Docker and its providers
bash provision.sh --skip-docker
```

> Re-running `provision.sh` with different flags regenerates the `docker-compose.yml` and updates the systemd service. The `.env` file is **never overwritten** — existing credentials are preserved.

---

## .gitconfig

Shared Git configuration, tracked at the repo root and symlinked to `$HOME/.gitconfig` on **both** Windows (by `windows.ps1`) and WSL (by `provision.sh`, via `setup-wsl.ps1` passing `--repo-path`). Editing this one file changes Git behavior identically in both environments — no need to update two config blocks.

It only holds shared defaults (delta as pager, linear-history rebase workflow, merge/diff behavior, aliases) — **never** personal identity. `user.name`/`user.email` are written to a separate, untracked `~/.gitconfig.local`, which `.gitconfig` includes automatically. That file is populated from `windows.config.psd1`'s `Git` block (see [Configuration](#configuration)), so filling in your identity once applies it on both OSes.

If `~/.gitconfig` already exists as a regular file when the scripts run, it's backed up to `~/.gitconfig.bak` before the symlink is created.

Running `provision.sh` standalone (without `setup-wsl.ps1`, e.g. `bash provision.sh` inside an already-provisioned WSL) falls back to applying the same settings inline via `git config --global`, since there's no repo path to symlink to in that case.

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

### .env setup

Before starting the services, copy the example file and adjust credentials:

```bash
# Inside WSL — ~/providers/ is created automatically by provision.sh
cd ~/providers
cp .env.example .env
nano .env   # or use your preferred editor
```

The `.env` file controls all service credentials and ports:

```ini
# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres      # change before first start
POSTGRES_PORT=5432

# Redis
REDIS_PORT=6379

# pgAdmin — http://localhost:5050
PGADMIN_EMAIL=admin@admin.com
PGADMIN_PASSWORD=admin          # change before first start
PGADMIN_PORT=5050

# Portainer — http://localhost:9000
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443

# Timezone
TZ=America/Sao_Paulo
```

> **Note:** If `provision.sh` already started the services before you edited `.env`, run `pvdown && pvup` to restart with the new credentials.

### Services

| Service    | URL / Port            | Default credentials         |
| ---------- | --------------------- | --------------------------- |
| PostgreSQL | `localhost:5432`      | `postgres` / `postgres`     |
| Redis      | `localhost:6379`      | —                           |
| pgAdmin    | http://localhost:5050 | `admin@admin.com` / `admin` |
| Portainer  | http://localhost:9000 | (set on first access)       |

### Shell aliases available after provisioning

```bash
pvup        # docker compose up -d
pvdown      # docker compose down
pvlogs      # docker compose logs -f
pvps        # docker compose ps
pvrestart   # docker compose restart
```

---

## Tools

See [`docs/tools.md`](./docs/tools.md) for the full catalog, split into [Windows tools](./docs/tools-windows.md) and [WSL tools](./docs/tools-wsl.md).

---

## License

[MIT](./LICENSE)
