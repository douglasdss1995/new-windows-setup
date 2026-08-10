# setup-wsl.sh

Provisions the development environment inside Ubuntu. See [`docs/tools-wsl.md`](./tools-wsl.md) for the full tool catalog.

**What it installs:**

| Step         | Content                                                                                |
| ------------ | ---------------------------------------------------------------------------------------- |
| System       | Build dependencies, curl, wget, make                                                     |
| Shell        | Zsh, Oh My Zsh, plugins (autosuggestions, syntax-highlighting, completions)              |
| mise         | Universal runtime manager                                                                |
| Python       | Latest version via mise + uv + poetry, black, ruff, mypy, pytest, ipython               |
| Node.js      | LTS via mise + pnpm + Angular CLI, ESLint, Prettier                                      |
| CLI          | ripgrep, fd, bat, eza, fzf, zoxide, delta, jq, yq, gh                                    |
| direnv       | Per-directory environment variable loading (`.envrc` files)                              |
| Docker       | Native daemon (no Docker Desktop) + systemd enable (auto-start)                          |
| Providers    | PostgreSQL, Redis, pgAdmin, Portainer via compose at `~/providers/` (see [Providers](./providers.md)) |
| Git          | Shared `.gitconfig` symlinked from the repo (see [.gitconfig](./gitconfig.md))           |
| Shell config | `.zshrc` with aliases for Django, Git, Docker, Python, Providers (`pvup`, `pvdown`...)  |

**Flags:**

```bash
bash setup-wsl.sh                        # everything
bash setup-wsl.sh --skip-docker          # without Docker (also skips all providers)
bash setup-wsl.sh --skip-python          # without Python
bash setup-wsl.sh --skip-node            # without Node

# Individual provider flags (requires Docker)
bash setup-wsl.sh --skip-postgres        # without PostgreSQL (also skips pgAdmin)
bash setup-wsl.sh --skip-redis           # without Redis
bash setup-wsl.sh --skip-pgadmin         # without pgAdmin
bash setup-wsl.sh --skip-portainer       # without Portainer
```

Flags can be combined freely:

```bash
# Docker + only Redis (no Postgres, pgAdmin or Portainer)
bash setup-wsl.sh --skip-postgres --skip-pgadmin --skip-portainer

# Everything except Docker and its providers
bash setup-wsl.sh --skip-docker
```

> Re-running `setup-wsl.sh` with different flags regenerates the `docker-compose.yml` and updates the systemd service. The `.env` file is **never overwritten** — existing credentials are preserved.
