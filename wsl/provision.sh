#!/usr/bin/env bash
# =============================================================================
# provision.sh — WSL environment provisioning for Django + Angular dev
# Usage: bash provision.sh [--skip-docker] [--skip-node] [--skip-python]
#                          [--skip-postgres] [--skip-redis]
#                          [--skip-pgadmin] [--skip-minio] [--skip-portainer]
#                          [--repo-path=/mnt/x/path/to/new-windows-setup]
#                          [--git-username="Your Name"] [--git-email=you@example.com]
# =============================================================================

set -euo pipefail

# Compute paths once — used for sourcing lib files and REPO_PATH auto-detect
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Source library functions (definitions only — nothing executes yet)
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/system.sh"
source "$LIB_DIR/zsh.sh"
source "$LIB_DIR/mise.sh"
source "$LIB_DIR/python.sh"
source "$LIB_DIR/node.sh"
source "$LIB_DIR/cli_tools.sh"
source "$LIB_DIR/docker.sh"
source "$LIB_DIR/git_config.sh"
source "$LIB_DIR/providers.sh"
source "$LIB_DIR/summary.sh"

# =============================================================================
# Flags
# =============================================================================
SKIP_DOCKER=false
SKIP_NODE=false
SKIP_PYTHON=false
SKIP_POSTGRES=false
SKIP_REDIS=false
SKIP_PGADMIN=false
SKIP_PORTAINER=false
SKIP_MINIO=false
REPO_PATH=""
GIT_USERNAME=""
GIT_EMAIL=""

for arg in "$@"; do
  case $arg in
    --skip-docker)      SKIP_DOCKER=true ;;
    --skip-node)        SKIP_NODE=true ;;
    --skip-python)      SKIP_PYTHON=true ;;
    --skip-postgres)    SKIP_POSTGRES=true ;;
    --skip-redis)       SKIP_REDIS=true ;;
    --skip-pgadmin)     SKIP_PGADMIN=true ;;
    --skip-portainer)   SKIP_PORTAINER=true ;;
    --skip-minio)       SKIP_MINIO=true ;;
    --repo-path=*)      REPO_PATH="${arg#*=}" ;;
    --git-username=*)   GIT_USERNAME="${arg#*=}" ;;
    --git-email=*)      GIT_EMAIL="${arg#*=}" ;;
  esac
done

# Fallback: if not passed explicitly (e.g. running this script standalone,
# outside the setup-wsl.ps1 flow), auto-detect a sibling .gitconfig one
# directory up (repo root), in case this script is run from a full clone.
if [ -z "$REPO_PATH" ]; then
  if [ -f "$SCRIPT_DIR/../.gitconfig" ]; then
    REPO_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
  fi
fi

# =============================================================================
# Execution — ordered call block
# =============================================================================
provision_system_update
provision_base_deps
provision_zsh_ohmyzsh
provision_mise_install

[ "$SKIP_PYTHON" = false ] && provision_python
[ "$SKIP_NODE" = false ]   && provision_node

provision_cli_tools

[ "$SKIP_DOCKER" = false ] && provision_docker

provision_git_config
provision_zshrc_config

[ "$SKIP_DOCKER" = false ] && provision_providers

provision_summary
