# Providers

`setup-wsl.sh` automatically configures shared services at `~/providers/` inside WSL and creates a systemd service to start them automatically.

## .env setup

Before starting the services, copy the example file and adjust credentials:

```bash
# Inside WSL — ~/providers/ is created automatically by setup-wsl.sh
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

> **Note:** If `setup-wsl.sh` already started the services before you edited `.env`, run `pvdown && pvup` to restart with the new credentials.

## Services

| Service    | URL / Port            | Default credentials         |
| ---------- | ---------------------- | ---------------------------- |
| PostgreSQL | `localhost:5432`      | `postgres` / `postgres`     |
| Redis      | `localhost:6379`      | —                            |
| pgAdmin    | http://localhost:5050 | `admin@admin.com` / `admin` |
| Portainer  | http://localhost:9000 | (set on first access)        |

## Shell aliases available after provisioning

```bash
pvup        # docker compose up -d
pvdown      # docker compose down
pvlogs      # docker compose logs -f
pvps        # docker compose ps
pvrestart   # docker compose restart
```
