#!/usr/bin/env bash
# =============================================================================
# provision.sh — WSL environment provisioning for Django + Angular dev
# Usage: bash provision.sh [--skip-docker] [--skip-node] [--skip-python]
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Flags
# -----------------------------------------------------------------------------
SKIP_DOCKER=false
SKIP_NODE=false
SKIP_PYTHON=false

for arg in "$@"; do
  case $arg in
    --skip-docker) SKIP_DOCKER=true ;;
    --skip-node)   SKIP_NODE=true ;;
    --skip-python) SKIP_PYTHON=true ;;
  esac
done

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }

step() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN} $*${NC}"
  echo -e "${GREEN}========================================${NC}"
}

# -----------------------------------------------------------------------------
# 1. System update
# -----------------------------------------------------------------------------
step "Updating system packages"
sudo apt-get update -qq && sudo apt-get upgrade -y -qq
success "System updated"

# -----------------------------------------------------------------------------
# 2. Base dependencies
# -----------------------------------------------------------------------------
step "Installing base dependencies"
sudo apt-get install -y -qq \
  build-essential \
  curl \
  wget \
  git \
  unzip \
  zip \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  apt-transport-https \
  libssl-dev \
  libffi-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  libncursesw5-dev \
  libxml2-dev \
  libxmlsec1-dev \
  liblzma-dev \
  tk-dev \
  xz-utils \
  llvm \
  make \
  gpg
success "Base dependencies installed"

# -----------------------------------------------------------------------------
# 3. Zsh + Oh My Zsh
# -----------------------------------------------------------------------------
step "Installing Zsh + Oh My Zsh"
sudo apt-get install -y -qq zsh

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  success "Oh My Zsh installed"
else
  warn "Oh My Zsh already installed, skipping"
fi

# Plugins: zsh-autosuggestions and zsh-syntax-highlighting
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
  git clone --depth=1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
fi

success "Zsh plugins installed"

# Set zsh as the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  sudo chsh -s "$(which zsh)" "$USER"
  success "Zsh set as default shell"
fi

# -----------------------------------------------------------------------------
# 4. mise (universal runtime version manager)
# -----------------------------------------------------------------------------
step "Installing mise"
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  export PATH="$HOME/.local/bin:$PATH"
  success "mise installed"
else
  warn "mise already installed, updating"
  mise self-update || true
fi

# Activate mise in .zshrc and .bashrc
for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
  if ! grep -q 'mise activate' "$RC" 2>/dev/null; then
    echo '' >> "$RC"
    echo '# mise - runtime version manager' >> "$RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
    echo 'eval "$(mise activate bash)"' >> "$RC"
  fi
done

# Fix activation in .zshrc for zsh
if grep -q 'mise activate bash' "$HOME/.zshrc"; then
  sed -i 's/mise activate bash/mise activate zsh/' "$HOME/.zshrc"
fi

success "mise configured in shell"

# -----------------------------------------------------------------------------
# 5. Python via mise
# -----------------------------------------------------------------------------
if [ "$SKIP_PYTHON" = false ]; then
  step "Installing Python via mise"
  mise use --global python@latest
  eval "$(mise activate bash)"

  # uv - ultra-fast package manager
  if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  # Global Python tools via uv
  uv tool install poetry
  uv tool install black
  uv tool install ruff
  uv tool install mypy
  uv tool install pytest
  uv tool install ipython
  uv tool install httpie
  uv tool install pre-commit

  # Ensure uv is in shell PATH
  for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if ! grep -q '.local/bin' "$RC" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$RC"
    fi
  done

  success "Python and tools installed"
fi

# -----------------------------------------------------------------------------
# 6. Node.js via mise
# -----------------------------------------------------------------------------
if [ "$SKIP_NODE" = false ]; then
  step "Installing Node.js via mise"
  mise use --global node@lts
  eval "$(mise activate bash)"

  # pnpm
  if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm
  fi

  # Angular CLI and global tools
  pnpm add -g @angular/cli
  pnpm add -g typescript
  pnpm add -g eslint
  pnpm add -g prettier

  success "Node.js and tools installed"
fi

# -----------------------------------------------------------------------------
# 7. Modern CLI tools
# -----------------------------------------------------------------------------
step "Installing CLI tools"

# ripgrep
if ! command -v rg &>/dev/null; then
  sudo apt-get install -y -qq ripgrep
fi

# fd
if ! command -v fd &>/dev/null; then
  sudo apt-get install -y -qq fd-find
  # fd-find installs as fdfind - create symlink
  if ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
  fi
fi

# bat
if ! command -v bat &>/dev/null; then
  sudo apt-get install -y -qq bat
  # bat may install as batcat
  if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
  fi
fi

# fzf
if ! command -v fzf &>/dev/null; then
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
fi

# zoxide
if ! command -v zoxide &>/dev/null; then
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# delta (improved git diff)
if ! command -v delta &>/dev/null; then
  DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -sLo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb
  rm /tmp/delta.deb
fi

# eza (modern ls)
if ! command -v eza &>/dev/null; then
  sudo apt-get install -y -qq gpg
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -qq && sudo apt-get install -y -qq eza
fi

# jq
if ! command -v jq &>/dev/null; then
  sudo apt-get install -y -qq jq
fi

# yq
if ! command -v yq &>/dev/null; then
  YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d'"' -f4)
  sudo wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
  sudo chmod +x /usr/local/bin/yq
fi

# GitHub CLI
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -qq && sudo apt-get install -y -qq gh
fi

# direnv
if ! command -v direnv &>/dev/null; then
  sudo apt-get install -y -qq direnv
fi

success "CLI tools installed"

# -----------------------------------------------------------------------------
# 8. Docker (native daemon in WSL, no Docker Desktop)
# -----------------------------------------------------------------------------
if [ "$SKIP_DOCKER" = false ]; then
  step "Installing Docker"
  if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    success "Docker installed - log out/in to use without sudo"
  else
    warn "Docker already installed, skipping"
  fi

  # Enable and start Docker service via systemd (auto-start with WSL)
  sudo systemctl enable docker
  sudo systemctl start docker 2>/dev/null || true
  success "Docker configured to start automatically via systemd"
fi

# -----------------------------------------------------------------------------
# 9. Git - global configuration
# -----------------------------------------------------------------------------
step "Configuring Git"

# delta as git pager
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.light false
git config --global delta.line-numbers true
git config --global delta.side-by-side false
git config --global merge.conflictstyle diff3
git config --global diff.colorMoved default

# General useful settings
git config --global pull.rebase false
git config --global init.defaultBranch main
git config --global core.autocrlf input
git config --global core.editor "code --wait"

success "Git configured"

# -----------------------------------------------------------------------------
# 10. .zshrc - configuration and aliases
# -----------------------------------------------------------------------------
step "Configuring .zshrc"

ZSHRC="$HOME/.zshrc"

# Update plugins in .zshrc
if grep -q '^plugins=' "$ZSHRC"; then
  sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions z fzf)/' "$ZSHRC"
fi

# Aliases block - only add if not already present
if ! grep -q '# === provision aliases ===' "$ZSHRC"; then
cat >> "$ZSHRC" << 'EOF'

# === provision aliases ===

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ll='eza -lah --git --icons'
alias ls='eza --icons'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --paging=never'

# Git
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# Django
alias pm='python manage.py'
alias pmr='python manage.py runserver'
alias pmm='python manage.py migrate'
alias pmmk='python manage.py makemigrations'
alias pmsh='python manage.py shell'

# Python
alias py='python'
alias pip='uv pip'
alias venv='uv venv'

# Docker
alias dk='docker'
alias dkc='docker compose'
alias dkps='docker ps'
alias dkpsa='docker ps -a'

# Providers (PostgreSQL, Redis, pgAdmin, Portainer)
alias pvup='docker container prune -f 2>/dev/null; docker compose -f ~/providers/docker-compose.yml up -d --remove-orphans --force-recreate'
alias pvdown='docker compose -f ~/providers/docker-compose.yml down --remove-orphans; docker container prune -f 2>/dev/null'
alias pvlogs='docker compose -f ~/providers/docker-compose.yml logs -f'
alias pvps='docker compose -f ~/providers/docker-compose.yml ps'
alias pvrestart='docker compose -f ~/providers/docker-compose.yml restart'

# zoxide as cd
eval "$(zoxide init zsh)"

# fzf keybindings
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# direnv
eval "$(direnv hook zsh)"

EOF
fi

# direnv hook for bash
if ! grep -q 'direnv hook bash' "$HOME/.bashrc" 2>/dev/null; then
  echo '' >> "$HOME/.bashrc"
  echo '# direnv' >> "$HOME/.bashrc"
  echo 'eval "$(direnv hook bash)"' >> "$HOME/.bashrc"
fi

success ".zshrc configured"

# -----------------------------------------------------------------------------
# 11. Providers (PostgreSQL, Redis, pgAdmin, Portainer)
# -----------------------------------------------------------------------------
if [ "$SKIP_DOCKER" = false ]; then
  step "Configuring Providers (PostgreSQL, Redis, pgAdmin, Portainer)"

  PROVIDERS_DIR="$HOME/providers"
  mkdir -p "$PROVIDERS_DIR/providers/postgres/init"
  mkdir -p "$PROVIDERS_DIR/providers/redis"
  mkdir -p "$PROVIDERS_DIR/providers/pgadmin"

  # docker-compose.yml
  cat > "$PROVIDERS_DIR/docker-compose.yml" << 'COMPOSE_EOF'
# =============================================================================
# docker-compose.yml - Providers (Shared Services)
# Services: PostgreSQL, Redis, pgAdmin, Portainer
# Usage: docker compose up -d
# =============================================================================

services:

  postgres:
    image: postgres:15-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
      POSTGRES_DB: ${POSTGRES_DB:-postgres}
      TZ: ${TZ:-America/Sao_Paulo}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./providers/postgres/init:/docker-entrypoint-initdb.d
    # Performance tuning for local development (not suitable for production).
    # shared_buffers:             PostgreSQL's main memory cache for data pages (~25% of available RAM).
    # max_connections:            Max simultaneous client connections; each one pre-allocates memory.
    # work_mem:                   Memory per sort/hash operation per query — low values spill to disk.
    # maintenance_work_mem:       Memory for VACUUM, ANALYZE and CREATE INDEX operations.
    # effective_cache_size:       Hints to the query planner how much OS-level cache is available;
    #                             without this the planner underestimates and picks worse query plans.
    # wal_buffers:                Write-Ahead Log buffer in shared memory; reduces WAL I/O under write load.
    # synchronous_commit:         "off" = writes return immediately without waiting for WAL flush to disk.
    #                             Biggest dev performance win — at most ~600ms of transactions lost on crash.
    # checkpoint_completion_target: Spreads checkpoint I/O over this fraction of the checkpoint interval,
    #                             avoiding I/O spikes that stall queries.
    # random_page_cost:           Cost estimate for a random page read. Default (4.0) is tuned for spinning
    #                             disks — set to 1.1 for SSD/Docker so the planner prefers index scans.
    # effective_io_concurrency:   Number of concurrent I/O requests the disk can handle; 200 for SSD/Docker
    #                             improves parallelism in bitmap index scans.
    command: >
      postgres
        -c shared_buffers=512MB
        -c max_connections=100
        -c work_mem=32MB
        -c maintenance_work_mem=256MB
        -c effective_cache_size=1536MB
        -c wal_buffers=16MB
        -c synchronous_commit=off
        -c checkpoint_completion_target=0.9
        -c random_page_cost=1.1
        -c effective_io_concurrency=200
    networks:
      - shared-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis_data:/data
      - ./providers/redis/redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    networks:
      - shared-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_EMAIL:-admin@admin.com}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:-admin}
      TZ: ${TZ:-America/Sao_Paulo}
    ports:
      - "${PGADMIN_PORT:-5050}:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
      - ./providers/pgadmin/servers.json:/pgadmin4/servers.json:ro
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - shared-network

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "${PORTAINER_HTTP_PORT:-9000}:9000"
      - "${PORTAINER_HTTPS_PORT:-9443}:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - shared-network

networks:
  shared-network:
    name: shared-network
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  pgadmin_data:
  portainer_data:
COMPOSE_EOF

  # .env - only create if it doesn't exist (preserve customizations)
  if [ ! -f "$PROVIDERS_DIR/.env" ]; then
    cat > "$PROVIDERS_DIR/.env" << 'ENV_EOF'
# =============================================================================
# .env - Providers (Shared Services)
# =============================================================================

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
POSTGRES_PORT=5432

# Redis
REDIS_PORT=6379

# pgAdmin - http://localhost:5050
PGADMIN_EMAIL=admin@admin.com
PGADMIN_PASSWORD=admin
PGADMIN_PORT=5050

# Portainer - http://localhost:9000
PORTAINER_HTTP_PORT=9000
PORTAINER_HTTPS_PORT=9443

# Timezone
TZ=America/Sao_Paulo
ENV_EOF
    warn ".env file created with default values - edit passwords at: $PROVIDERS_DIR/.env"
  else
    warn ".env already exists at $PROVIDERS_DIR/.env - kept unchanged"
  fi

  # redis.conf
  cat > "$PROVIDERS_DIR/providers/redis/redis.conf" << 'REDIS_EOF'
# ==============================================
# Redis - Configuration
# ==============================================

bind 0.0.0.0
port 6379
protected-mode no

# Persistence
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000

# Memory
maxmemory 256mb
maxmemory-policy allkeys-lru

# Logging
loglevel notice

# Timeout
timeout 0
tcp-keepalive 300

# Databases
databases 16
REDIS_EOF

  # postgres init
  cat > "$PROVIDERS_DIR/providers/postgres/init/01-init-db.sql" << 'SQL_EOF'
-- =============================================================================
-- 01-init-db.sql - PostgreSQL initialization
-- =============================================================================

-- Useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

DO $$
BEGIN
  RAISE NOTICE 'PostgreSQL initialized successfully!';
END $$;
SQL_EOF

  # pgadmin servers.json
  cat > "$PROVIDERS_DIR/providers/pgadmin/servers.json" << 'JSON_EOF'
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL Local",
            "Group": "Servers",
            "Host": "postgres",
            "Port": 5432,
            "MaintenanceDB": "postgres",
            "Username": "postgres",
            "SSLMode": "prefer"
        }
    }
}
JSON_EOF

  # systemd service for auto-starting providers with WSL
  # Always overwrite so re-running provision.sh applies the latest configuration.
  PROVIDERS_SERVICE="/etc/systemd/system/providers.service"
  sudo tee "$PROVIDERS_SERVICE" > /dev/null << EOF
[Unit]
Description=Dev Providers (PostgreSQL, Redis, pgAdmin, Portainer)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PROVIDERS_DIR
# Wait up to 60 s for the Docker daemon to be truly responsive, not just started.
# WSL mirrored networking takes a moment to stabilise after boot; starting containers
# before that causes broken port bindings that require manual cleanup.
ExecStartPre=/bin/bash -c 'i=0; until docker info >/dev/null 2>&1; do i=\$((i+1)); [ \$i -ge 30 ] && exit 1; sleep 2; done'
ExecStartPre=-/usr/bin/docker container prune -f
ExecStart=/usr/bin/docker compose up -d --remove-orphans --force-recreate
ExecStop=/usr/bin/docker compose down --remove-orphans
ExecStopPost=-/usr/bin/docker container prune -f
TimeoutStartSec=180
User=$USER

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl daemon-reload
  if ! systemctl is-enabled providers.service &>/dev/null; then
    sudo systemctl enable providers.service
    success "Providers service enabled - starts automatically with WSL"
  else
    success "Providers service updated"
  fi

  success "Providers configured at: $PROVIDERS_DIR"
  info "pgAdmin   -> http://localhost:5050  (admin@admin.com / admin)"
  info "Portainer -> http://localhost:9000"
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Provisioning complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Restart terminal or run: exec zsh"
echo "  2. Configure Git: git config --global user.name 'Your Name'"
echo "  3. Configure Git: git config --global user.email 'your@email.com'"
echo "  4. Authenticate with GitHub: gh auth login"
if [ "$SKIP_DOCKER" = false ]; then
  echo "  5. For Docker without sudo: restart WSL session (wsl --shutdown in PowerShell)"
  echo "  6. Start providers:  pvup   (or: cd ~/providers && docker compose up -d)"
  echo "     - pgAdmin:        http://localhost:5050  (admin@admin.com / admin)"
  echo "     - Portainer:      http://localhost:9000"
  echo "     - PostgreSQL:     localhost:5432"
  echo "     - Redis:          localhost:6379"
fi
echo ""
