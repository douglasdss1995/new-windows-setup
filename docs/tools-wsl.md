# WSL Tools

Tools installed inside the Ubuntu WSL environment by `provision.sh`. All Docker-based services run here; nothing requires Docker Desktop.

---

## Runtime Managers

| Tool | Description |
|---|---|
| [mise](https://mise.jdx.dev/) | Universal runtime version manager — manages Python, Node.js, Java and more |
| [SDKMAN](https://sdkman.io/) | JVM SDK manager for Java, Kotlin, Groovy (optional, alongside mise) |

> `mise` is also installed on Windows by `windows.ps1` for use outside WSL.

---

## Shell

| Tool | Description |
|---|---|
| [Zsh](https://www.zsh.org/) | Default shell inside WSL |
| [Oh My Zsh](https://ohmyz.sh/) | Zsh framework with plugin and theme support |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Fish-like command suggestions from history |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Fish-like syntax highlighting in the prompt |
| [zsh-completions](https://github.com/zsh-users/zsh-completions) | Additional tab completions |

---

## Python Development Tools

Installed via [mise](https://mise.jdx.dev/) (runtime) and [uv](https://github.com/astral-sh/uv) (tooling).

| Tool | Description |
|---|---|
| [Python](https://www.python.org/) | Latest stable via `mise use --global python@latest` |
| [uv](https://github.com/astral-sh/uv) | Ultra-fast package and environment manager (`pip`, `venv`, `tool install`) |
| [poetry](https://python-poetry.org/) | Modern project and dependency management |
| [black](https://black.readthedocs.io/) | Opinionated code formatter |
| [ruff](https://github.com/astral-sh/ruff) | Ultra-fast linter (replaces flake8, isort and more) |
| [mypy](https://mypy-lang.org/) | Static type checker |
| [pytest](https://pytest.org/) | Testing framework |
| [ipython](https://ipython.org/) | Enhanced interactive Python shell |
| [httpie](https://httpie.io/) | HTTP client for the command line |
| [pre-commit](https://pre-commit.com/) | Git hooks for pre-commit validation |

> `uv` is also installed on Windows by `windows.ps1`.

---

## Node.js / Angular Tools

Installed via [mise](https://mise.jdx.dev/) (runtime) and [pnpm](https://pnpm.io/) (packages).

| Tool | Description |
|---|---|
| [Node.js LTS](https://nodejs.org/) | Via `mise use --global node@lts` |
| [pnpm](https://pnpm.io/) | Fast and efficient package manager |
| [Angular CLI](https://angular.dev/tools/cli) | Project creation and management |
| [TypeScript](https://www.typescriptlang.org/) | Typed JavaScript |
| [ESLint](https://eslint.org/) | JavaScript/TypeScript linter |
| [Prettier](https://prettier.io/) | Code formatter |
| [Jest](https://jestjs.io/) | JavaScript testing framework |
| [Nx](https://nx.dev/) | Monorepo and build tooling for Angular |

> `pnpm` is also installed on Windows by `windows.ps1`.

---

## CLI Utilities

| Tool | Description |
|---|---|
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | Ultra-fast file search |
| [fd](https://github.com/sharkdp/fd) | Modern alternative to `find` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting |
| [eza](https://github.com/eza-community/eza) | Modern alternative to `ls` |
| [delta](https://github.com/dandavison/delta) | Diff viewer configured as Git pager |
| [fzf](https://github.com/junegunn/fzf) | Command-line fuzzy finder |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Fast directory navigation (replaces `cd`) |
| [jq](https://jqlang.github.io/jq/) | JSON processor |
| [yq](https://github.com/mikefarah/yq) | YAML processor |
| [GitHub CLI (gh)](https://cli.github.com/) | Manage GitHub from the command line |

> All of these are also installed on Windows by `windows.ps1`.

---

## Environment Management

| Tool | Description |
|---|---|
| [direnv](https://direnv.net/) | Loads and unloads environment variables automatically per directory |

direnv reads `.envrc` files when you `cd` into a directory and exports the variables into the current shell. On exit it unloads them. Typical uses:

- **Per-project `.env` injection** without sourcing files manually
- **Switching virtual environments** automatically (`layout python`, `layout node`)
- **Project-specific `PATH` entries** (e.g. local `bin/` directories)

**Shell hook** (added to `.zshrc` and `.bashrc` by `provision.sh`):
```bash
eval "$(direnv hook zsh)"
```

**Typical `.envrc` patterns:**
```bash
# Load a .env file
dotenv

# Activate a Python virtual environment
layout python3

# Add local scripts to PATH
PATH_add bin

# Set project-specific vars
export DATABASE_URL=postgres://localhost/mydb
```

> Run `direnv allow` once after creating or editing an `.envrc` file in a project.

---

## Docker and Infrastructure

> Docker runs as a **native daemon inside WSL** — no Docker Desktop required. Lower memory usage (~50–150 MB vs ~1 GB), full systemd control and automatic startup with WSL.

| Tool | Description |
|---|---|
| [Docker Engine](https://docs.docker.com/engine/) | Native Docker daemon installed via `get.docker.com` |
| [Docker Compose](https://docs.docker.com/compose/) | Bundled with Docker Engine (v2 plugin) |
| [Portainer](https://www.portainer.io/) | Web UI for Docker containers (runs via providers compose) |

---

## Providers (Shared Services)

Infrastructure services shared across all projects, managed at `~/providers/docker-compose.yml` and started automatically via a systemd service when WSL boots.

| Service | Image | Port | Description |
|---|---|---|---|
| PostgreSQL | `postgres:15-alpine` | 5432 | Primary relational database |
| Redis | `redis:7-alpine` | 6379 | Cache, queues (Celery) and sessions |
| pgAdmin | `dpage/pgadmin4` | 5050 | Web UI for PostgreSQL |
| Portainer | `portainer/portainer-ce` | 9000 / 9443 | Web UI for managing containers |

Each provider can be individually included or excluded via `--skip-*` flags when running `provision.sh`:

```bash
bash provision.sh --skip-postgres        # no PostgreSQL (also skips pgAdmin)
bash provision.sh --skip-redis           # no Redis
bash provision.sh --skip-pgadmin         # no pgAdmin
bash provision.sh --skip-portainer       # no Portainer

# Example: Docker + only Redis
bash provision.sh --skip-postgres --skip-pgadmin --skip-portainer
```

Re-running with different flags regenerates `docker-compose.yml` and updates the systemd service.

Credentials and ports are controlled by `~/providers/.env`. Copy `.env.example` and edit before first start:

```bash
cd ~/providers
cp .env.example .env
nano .env
```

**Shell aliases** (available after provisioning):

```bash
pvup        # docker compose up -d
pvdown      # docker compose down
pvlogs      # docker compose logs -f
pvps        # docker compose ps
pvrestart   # docker compose restart
```

> **Why Redis in compose and not native?** Redis is shared infrastructure (like Postgres). There's no benefit in installing it natively in WSL. The `redis.conf` limits memory to 256 MB with `allkeys-lru` policy and its lifecycle stays consistent with the other services.
