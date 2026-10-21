# setup-wsl.sh

Provisions the development environment inside Debian. See [`docs/tools-wsl.md`](./tools-wsl.md) for the full tool catalog.

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
| Providers    | Valkey, Portainer via compose at `~/providers/`; PostgreSQL and pgAdmin are opt-in (see [Providers](./providers.md)) |
| Git          | Local `~/.gitconfig` that includes the repo's shared defaults (see [.gitconfig](./gitconfig.md)) |
| Shell config | `.zshrc` with aliases for Django, Git, Docker, Python, Providers (`pvup`, `pvdown`...)  |

**Flags:**

```bash
bash wsl/setup-wsl.sh                        # everything
bash wsl/setup-wsl.sh --skip-docker          # without Docker (also skips all providers)
bash wsl/setup-wsl.sh --with-nvidia          # NVIDIA Container Toolkit for `docker --gpus` (opt-in; needs Docker + Windows NVIDIA driver)
bash wsl/setup-wsl.sh --skip-python          # without Python
bash wsl/setup-wsl.sh --skip-node            # without Node

# Individual provider flags (requires Docker)
bash wsl/setup-wsl.sh --with-postgres        # also install PostgreSQL (opt-in)
bash wsl/setup-wsl.sh --with-pgadmin         # also install pgAdmin (requires --with-postgres)
bash wsl/setup-wsl.sh --with-minio           # add MinIO to the compose file (opt-in, discontinued; never auto-starts)
bash wsl/setup-wsl.sh --with-seaweedfs       # add SeaweedFS to the compose file (opt-in; never auto-starts)
bash wsl/setup-wsl.sh --skip-valkey          # without Valkey
bash wsl/setup-wsl.sh --skip-portainer       # without Portainer
```

MinIO and SeaweedFS are S3-compatible object storage, opt-in, and run as Docker Compose
**profiles**: `docker compose up -d` (and therefore the `providers.service` that runs at boot)
does not start them. Start them on demand:

```bash
cd ~/providers
docker compose --profile seaweedfs up -d seaweedfs   # S3 :8333, filer :8888, master :9333
docker compose --profile minio up -d minio           # S3 :9000, console :9001
docker compose --profile seaweedfs stop seaweedfs    # stop again
```

Flags can be combined freely:

```bash
# Docker + Valkey only (the default — PostgreSQL and pgAdmin are opt-in)
bash wsl/setup-wsl.sh

# Docker + Valkey + PostgreSQL + pgAdmin
bash wsl/setup-wsl.sh --with-postgres --with-pgadmin

# Everything except Docker and its providers
bash wsl/setup-wsl.sh --skip-docker
```

> Re-running `setup-wsl.sh` with different flags regenerates the `docker-compose.yml` and updates the systemd service. The `.env` file is **never overwritten** — existing credentials are preserved.
