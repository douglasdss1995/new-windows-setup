#!/usr/bin/env bash
# =============================================================================
# setup-wsl.sh — WSL environment provisioning for Django + Angular dev
# Usage: bash setup-wsl.sh [--skip-docker] [--skip-node] [--skip-python]
#                          [--with-postgres] [--skip-redis]
#                          [--with-pgadmin] [--skip-minio] [--skip-portainer]
#                          [--skip-gitkraken] [--skip-keyboard]
#                          [--keyboard-layout=br] [--keyboard-variant=abnt2]
#                          [--repo-path=/mnt/x/path/to/new-windows-setup]
#                          [--git-username="Your Name"] [--git-email=you@example.com]
# =============================================================================

set -euo pipefail

# Compute paths once — used for sourcing lib files and REPO_PATH auto-detect.
# This script lives under wsl/, alongside lib/*.sh.
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
source "$LIB_DIR/gitkraken.sh"
source "$LIB_DIR/git_config.sh"
source "$LIB_DIR/providers.sh"
source "$LIB_DIR/summary.sh"

# =============================================================================
# Flags
# =============================================================================
SKIP_DOCKER=false
SKIP_NODE=false
SKIP_PYTHON=false
# PostgreSQL and pgAdmin are opt-in (not needed by every project) — enable
# with --with-postgres / --with-pgadmin. All other providers default on.
SKIP_POSTGRES=true
SKIP_REDIS=false
SKIP_PGADMIN=true
SKIP_PORTAINER=false
SKIP_MINIO=false
SKIP_GITKRAKEN=false
SKIP_KEYBOARD=false
KEYBOARD_LAYOUT="br"
KEYBOARD_VARIANT="abnt2"
REPO_PATH=""
GIT_USERNAME=""
GIT_EMAIL=""

for arg in "$@"; do
  case $arg in
    --skip-docker)          SKIP_DOCKER=true ;;
    --skip-node)            SKIP_NODE=true ;;
    --skip-python)          SKIP_PYTHON=true ;;
    --with-postgres)        SKIP_POSTGRES=false ;;
    --skip-redis)           SKIP_REDIS=true ;;
    --with-pgadmin)         SKIP_PGADMIN=false ;;
    --skip-portainer)       SKIP_PORTAINER=true ;;
    --skip-minio)           SKIP_MINIO=true ;;
    --skip-gitkraken)       SKIP_GITKRAKEN=true ;;
    --skip-keyboard)        SKIP_KEYBOARD=true ;;
    --keyboard-layout=*)    KEYBOARD_LAYOUT="${arg#*=}" ;;
    --keyboard-variant=*)   KEYBOARD_VARIANT="${arg#*=}" ;;
    --repo-path=*)          REPO_PATH="${arg#*=}" ;;
    --git-username=*)       GIT_USERNAME="${arg#*=}" ;;
    --git-email=*)          GIT_EMAIL="${arg#*=}" ;;
  esac
done

# Fallback: if not passed explicitly (e.g. running this script standalone,
# outside the setup-wsl.ps1 flow), auto-detect the repo root's git/.gitconfig,
# in case this script is run from a full clone (repo root is one level up from
# this script's wsl/ directory).
if [ -z "$REPO_PATH" ]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [ -f "$REPO_ROOT/git/.gitconfig" ]; then
    REPO_PATH="$REPO_ROOT"
  fi
fi

# =============================================================================
# Execution — ordered call block
# Each step runs in isolation via run_step: a failure is logged and recorded
# in FAILED_STEPS, but does not stop the remaining steps from running.
# =============================================================================
run_step "system_update" provision_system_update
run_step "base_deps"     provision_base_deps
run_step "locale"        provision_locale
run_step "zsh_ohmyzsh"   provision_zsh_ohmyzsh
run_step "mise_install"  provision_mise_install

[ "$SKIP_PYTHON" = false ] && run_step "python" provision_python
[ "$SKIP_NODE" = false ]   && run_step "node"   provision_node

run_step "cli_tools" provision_cli_tools

[ "$SKIP_DOCKER" = false ] && run_step "docker" provision_docker

[ "$SKIP_GITKRAKEN" = false ] && run_step "gitkraken"       provision_gitkraken
[ "$SKIP_KEYBOARD" = false ]  && run_step "keyboard_layout" provision_keyboard_layout

run_step "git_config"    provision_git_config
run_step "zshrc_config"  provision_zshrc_config

[ "$SKIP_DOCKER" = false ] && run_step "providers" provision_providers

provision_summary

if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
  warn "Etapas com falha: ${FAILED_STEPS[*]}"
  warn "Revise as mensagens acima e rode novamente com as flags --skip-* para pular o que já funcionou."
  exit 1
fi
