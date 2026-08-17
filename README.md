# new-windows-setup

Automation for setting up a Windows development machine from scratch, focused on **Django** (Python) and **Angular** (TypeScript) projects, with support for multiple languages and tools.

---

## Overview

```
new-windows-setup/
├── ferramentas.md              # Complete catalog of recommended tools
├── setup-windows.ps1           # Installs all tools on Windows via winget/choco
├── setup-wsl.ps1               # Enables and configures WSL 2 + Debian
├── git-clone.ps1               # Batch-clones repos listed in git/git-repos.config.psd1
├── docs/                       # Per-file/config explanations (see Documentation below)
├── windows/
│   ├── windows.config.psd1.example # Configuration template (copy to windows.config.psd1)
│   ├── windows.config.psd1         # Your local configuration (gitignored, created by you)
│   └── themes/
│       └── amro.omp.json           # Oh My Posh prompt theme (default) - edit to customize
├── git/
│   ├── .gitconfig                    # Shared Git config, symlinked to $HOME/.gitconfig (Windows + WSL)
│   ├── git-repos.config.psd1.example # Repo-clone config template (copy to git-repos.config.psd1)
│   └── git-repos.config.psd1         # Your local configuration (gitignored, created by you)
└── wsl/
    ├── .wslconfig              # Global WSL configuration (memory, CPU, network)
    ├── wsl.conf                # Internal distro Linux configuration
    ├── setup-wsl.sh            # Provisions the dev environment inside Debian
    ├── lib/                    # setup-wsl.sh step implementations
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
  - `setup-windows.ps1` — Windows PowerShell 5.1 or PowerShell 7
  - `setup-wsl.ps1` — **PowerShell 7.6** or later (required)
- Internet connection

---

## Configuration

Both config files below are **gitignored** — only the `.example` templates are versioned. Before running any script, copy each template and fill it in:

```powershell
Copy-Item windows\windows.config.psd1.example windows\windows.config.psd1
Copy-Item git\git-repos.config.psd1.example git\git-repos.config.psd1
```

### windows/windows.config.psd1

Controls which tools are installed on Windows. Set each flag to `$true` (install) or `$false` (skip).

Start by filling in your Git identity. This is the **single source of truth** for your Git identity — `setup-windows.ps1` applies it on Windows, and `setup-wsl.ps1` reads the same file and passes it through to `setup-wsl.sh` so it's applied inside WSL too (see [.gitconfig](./docs/gitconfig.md)):

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

### git/git-repos.config.psd1

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

## Execution Policy

Windows blocks `.ps1` script execution by default. All commands in this README run scripts through `powershell -ExecutionPolicy Bypass -File ...`, which only bypasses the policy for that one process and changes nothing permanently on your machine.

If you'd rather change the policy for your user or the whole machine instead, see [docs/execution-policy.md](./docs/execution-policy.md) for the alternatives and how to check your current policy.

## Quick Start

### Step 1 — Install Windows tools

```powershell
# PowerShell as Administrator
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

At the end of execution the script displays:

```
Next steps:
  1. Restart the computer to apply PATH changes
  2. Authenticate with GitHub:
       gh auth login
  3. Configure WSL:
       powershell -ExecutionPolicy Bypass -File .\setup-wsl.ps1
```

See [docs/setup-windows.md](./docs/setup-windows.md) for the full list of what gets installed.

### Step 2 — Configure WSL

> **Requires PowerShell 7.6.** Open PowerShell 7 as Administrator before running this step.

```powershell
# PowerShell 7.6 as Administrator, from the repo root
powershell -ExecutionPolicy Bypass -File .\setup-wsl.ps1
```

**If Debian is not yet installed**, the script installs the distro, then automatically opens it in its own window and pauses:

```
[WARN] First run requires creating a user.
  Opening Debian in a new window - create your username and password there...
```

Create your username and password in that new window, then return to the original window and press Enter to let the script continue — no need to rerun it.

The script then applies the rest of the configuration and automatically runs `wsl/setup-wsl.sh` inside WSL. Details in [docs/setup-wsl-on-windows.md](./docs/setup-wsl-on-windows.md) and [docs/setup-wsl.md](./docs/setup-wsl.md).

### Step 3 — Clone repositories

After restarting, configure `git\git-repos.config.psd1` (see [Configuration](#configuration)) and run:

```powershell
# PowerShell — clones all repositories listed in git\git-repos.config.psd1
powershell -ExecutionPolicy Bypass -File .\git-clone.ps1
```

### Step 4 — Final configuration

Git identity and the shared `.gitconfig` were already applied automatically in Step 2 (from `windows/windows.config.psd1`, see [.gitconfig](./docs/gitconfig.md)). All that's left:

```bash
# Inside WSL
gh auth login
```

---

## Documentation

Detailed explanations of each script and config file live in [`docs/`](./docs/):

| Doc | Covers |
| --- | --- |
| [execution-policy.md](./docs/execution-policy.md) | Working around Windows' script execution block |
| [setup-windows.md](./docs/setup-windows.md) | What `setup-windows.ps1` installs and its "Next steps" output |
| [setup-wsl-on-windows.md](./docs/setup-wsl-on-windows.md) | What `setup-wsl.ps1` does and its first-run flow |
| [setup-wsl.md](./docs/setup-wsl.md) | What `wsl/setup-wsl.sh` provisions and its `--skip-*` flags |
| [gitconfig.md](./docs/gitconfig.md) | How the shared `.gitconfig` and identity are applied on both OSes |
| [wslconfig.md](./docs/wslconfig.md) | `.wslconfig` (memory/CPU/network) settings |
| [wsl-conf.md](./docs/wsl-conf.md) | `/etc/wsl.conf` settings inside the distro |
| [providers.md](./docs/providers.md) | The `~/providers/` Docker stack (Postgres, Redis, pgAdmin, Portainer) and its `.env` |
| [tools-windows.md](./docs/tools-windows.md) | Full catalog of Windows tools |
| [tools-wsl.md](./docs/tools-wsl.md) | Full catalog of WSL tools |

---

## License

[MIT](./LICENSE)
