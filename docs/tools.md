# Tools for Django + Angular Developer

Installation and configuration guide for a development machine focused on Django (Python) and Angular (TypeScript/JavaScript), with support for multiple languages.

---

## Package Managers and Runtimes

| Tool | Description |
|---|---|
| [Chocolatey](https://chocolatey.org/) | Package manager for Windows |
| [Winget](https://learn.microsoft.com/en-us/windows/package-manager/) | Native Windows package manager |
| [nvm-windows](https://github.com/coreybutler/nvm-windows) | Node.js version manager |
| [Node.js (LTS)](https://nodejs.org/) | JavaScript runtime (install via nvm) |
| [pyenv-win](https://github.com/pyenv-win/pyenv-win) | Python version manager |
| [Python 3.x](https://www.python.org/) | Python runtime (install via pyenv) |
| [mise](https://mise.jdx.dev/) | Universal runtime version manager (Python, Node, Java, Ruby, Go...) |
| [SDKMAN](https://sdkman.io/) | JVM SDK manager (Java, Kotlin, Groovy) |
| [Java JDK](https://adoptium.net/) | Java runtime (Eclipse Temurin recommended) |

---

## Terminal and Shell

| Tool | Description |
|---|---|
| [Windows Terminal](https://aka.ms/terminal) | Modern terminal with multi-shell support |
| [Git Bash](https://gitforwindows.org/) | Bash on Windows with Unix utilities |
| [PowerShell 7+](https://github.com/PowerShell/PowerShell) | Modern cross-platform shell |
| [Oh My Posh](https://ohmyposh.dev/) | Customizable prompt for any shell |
| [Starship](https://starship.rs/) | Fast cross-shell configurable prompt |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Fast directory navigation (replaces `cd`) |
| [fzf](https://github.com/junegunn/fzf) | Command-line fuzzy finder |

---

## Editors and IDEs

| Tool | Description |
|---|---|
| [VS Code](https://code.visualstudio.com/) | Primary editor - Django and Angular |
| [PyCharm Community/Professional](https://www.jetbrains.com/pycharm/) | Dedicated Python/Django IDE |
| [WebStorm](https://www.jetbrains.com/webstorm/) | Dedicated JavaScript/TypeScript/Angular IDE |
| [Cursor](https://cursor.sh/) | AI-powered editor (VS Code fork) |

---

## VS Code - Essential Extensions

### Python / Django

- `ms-python.python` - Python support
- `ms-python.vscode-pylance` - Python language server
- `ms-python.debugpy` - Python debugger
- `batisteo.vscode-django` - Django templates and snippets
- `formulahendry.auto-close-tag` - Automatic tag closing

### Angular / TypeScript

- `Angular.ng-template` - Official Angular support
- `ms-vscode.vscode-typescript-next` - TypeScript next
- `dbaeumer.vscode-eslint` - Integrated ESLint
- `esbenp.prettier-vscode` - Code formatting

### General

- `eamodio.gitlens` - Advanced Git in editor
- `mhutchie.git-graph` - Branch visualization
- `ms-azuretools.vscode-docker` - Docker support
- `ms-vscode-remote.remote-containers` - Dev Containers
- `PKief.material-icon-theme` - File icons
- `oderwat.indent-rainbow` - Colored indentation
- `streetsidesoftware.code-spell-checker` - Spell checker

---

## Git and Version Control

| Tool | Description |
|---|---|
| [Git](https://git-scm.com/) | Version control |
| [GitHub CLI (gh)](https://cli.github.com/) | Manage GitHub from the command line |
| [GitLens](https://gitkraken.com/gitlens) | VS Code extension for advanced Git |
| [GitKraken](https://www.gitkraken.com/) | Visual Git client (optional) |
| [pre-commit](https://pre-commit.com/) | Git hooks for pre-commit validation |

---

## Python - Development Tools

| Tool | Description |
|---|---|
| [pip](https://pip.pypa.io/) | Python package manager |
| [uv](https://github.com/astral-sh/uv) | Ultra-fast package/environment manager |
| [pipenv](https://pipenv.pypa.io/) | Virtual environments + dependencies |
| [poetry](https://python-poetry.org/) | Modern Python project management |
| [virtualenv](https://virtualenv.pypa.io/) | Isolated virtual environments |
| [black](https://black.readthedocs.io/) | Python code formatter |
| [ruff](https://github.com/astral-sh/ruff) | Ultra-fast Python linter |
| [mypy](https://mypy-lang.org/) | Static type checker for Python |
| [pytest](https://pytest.org/) | Testing framework |
| [ipython](https://ipython.org/) | Enhanced interactive Python shell |
| [httpie](https://httpie.io/) | HTTP client for command line |

---

## Node.js / Angular - Development Tools

| Tool | Description |
|---|---|
| [npm](https://www.npmjs.com/) | Node package manager |
| [pnpm](https://pnpm.io/) | Fast and efficient package manager |
| [Angular CLI](https://angular.io/cli) | Angular project creation and management |
| [ESLint](https://eslint.org/) | JavaScript/TypeScript linter |
| [Prettier](https://prettier.io/) | Code formatter |
| [Jest](https://jestjs.io/) | JavaScript testing framework |
| [Nx](https://nx.dev/) | Monorepo and build tools for Angular |

---

## Databases

| Tool | Description |
|---|---|
| [PostgreSQL](https://www.postgresql.org/) | Primary relational database for Django |
| [DBeaver](https://dbeaver.io/) | Universal database client (GUI) |
| [TablePlus](https://tableplus.com/) | Modern database client (GUI) |
| [Redis](https://redis.io/) | Cache, queues and sessions |
| [Redis Insight](https://redis.com/redis-enterprise/redis-insight/) | GUI for Redis |
| [SQLite Browser](https://sqlitebrowser.org/) | Visual editor for SQLite |
| [pgAdmin](https://www.pgadmin.org/) | PostgreSQL administration (GUI) |

---

## Docker and Infrastructure

> Docker runs via **native Docker Engine in WSL** - no Docker Desktop. Lower memory usage, full control via systemd and automatic startup with WSL.

| Tool | Description |
|---|---|
| [Docker Engine](https://docs.docker.com/engine/) | Native Docker daemon in WSL (no Docker Desktop) - ~50-150 MB vs ~1 GB for Desktop |
| [Docker Compose](https://docs.docker.com/compose/) | Local container orchestration |
| [Portainer](https://www.portainer.io/) | Web UI for managing Docker containers (runs via providers compose) |
| [WSL 2](https://learn.microsoft.com/en-us/windows/wsl/) | Linux on Windows - Docker Engine and providers run here |

### Providers (Shared Services)

Infrastructure services shared across projects, managed via `~/providers/docker-compose.yml` and started automatically with WSL.

| Service | Image | Port | Description |
|---|---|---|---|
| PostgreSQL | `postgres:15-alpine` | 5432 | Primary relational database |
| Redis | `redis:7-alpine` | 6379 | Cache, queues (Celery) and sessions |
| pgAdmin | `dpage/pgadmin4` | 5050 | Web UI for PostgreSQL |
| Portainer | `portainer/portainer-ce` | 9000 / 9443 | Web UI for managing containers |

> **Redis in compose or native?** Compose. Redis is a shared infrastructure service (like Postgres), there's no benefit in installing it natively in WSL. The `redis.conf` limits memory to 256 MB with `allkeys-lru` policy, and the lifecycle stays consistent with other services.

---

## API and HTTP Testing

| Tool | Description |
|---|---|
| [Postman](https://www.postman.com/) | Full REST/GraphQL client |
| [Insomnia](https://insomnia.rest/) | Alternative REST/GraphQL client |
| [Bruno](https://www.usebruno.com/) | Open-source file-based HTTP client |
| [curl](https://curl.se/) | Command-line HTTP client |

---

## CLI Utilities

| Tool | Description |
|---|---|
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | Ultra-fast file search |
| [fd](https://github.com/sharkdp/fd) | Modern alternative to `find` |
| [bat](https://github.com/sharkdp/bat) | Alternative to `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern alternative to `ls` |
| [delta](https://github.com/dandavison/delta) | Diff viewer for Git |
| [jq](https://jqlang.github.io/jq/) | JSON processor for command line |
| [yq](https://github.com/mikefarah/yq) | YAML processor for command line |
| [wget](https://www.gnu.org/software/wget/) | File download via command line |
| [make](https://www.gnu.org/software/make/) | Task automation via Makefile |
| [just](https://github.com/casey/just) | Modern alternative to make |

---

## Security and Authentication

| Tool | Description |
|---|---|
| [1Password](https://1password.com/) / [Bitwarden](https://bitwarden.com/) | Password manager |
| [OpenSSH](https://www.openssh.com/) | SSH client/server |
| [GPG (Gpg4win)](https://www.gpg4win.org/) | Commit signing and encryption |

---

## Productivity and Organization

| Tool | Description |
|---|---|
| [Obsidian](https://obsidian.md/) | Markdown notes / knowledge management |
| [Notion](https://www.notion.so/) | Documentation and project organization |
| [Slack](https://slack.com/) / [Discord](https://discord.com/) | Team communication |
| [ShareX](https://getsharex.com/) | Screenshots and screen recording |
| [PowerToys](https://github.com/microsoft/PowerToys) | Windows productivity utilities (FancyZones, etc.) |
| [Everything](https://www.voidtools.com/) | Ultra-fast file search on Windows |
| [AutoHotkey](https://www.autohotkey.com/) | Automation and keyboard shortcuts on Windows |

---

## Browsers

| Tool | Description |
|---|---|
| [Chrome](https://www.google.com/chrome/) | Web development - DevTools |
| [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) | Advanced dev tools |
| [Edge](https://www.microsoft.com/edge) | Alternative with Windows integration |

---

## Development Fonts

| Font | Description |
|---|---|
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) | Monospace font for code |
| [Fira Code](https://github.com/tonsky/FiraCode) | Font with ligatures for code |
| [Cascadia Code](https://github.com/microsoft/cascadia-code) | Microsoft font with ligatures |
| [Nerd Fonts](https://www.nerdfonts.com/) | Fonts with icons for terminal |
