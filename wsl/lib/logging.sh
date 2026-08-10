#!/usr/bin/env bash
# logging.sh — Logging and output helpers for setup-wsl.sh

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

# Runs a provisioning step in isolation: a failure is logged and recorded in
# FAILED_STEPS but does not abort the rest of setup-wsl.sh (set -e would
# otherwise kill the whole script on the first failing step).
FAILED_STEPS=()

run_step() {
  local step_name="$1"
  shift
  # Run in a subshell with its own explicit `set -e` so a failing command
  # still stops that step immediately (fail-fast within the step), while the
  # `if` here keeps the failure from tripping the outer script's errexit.
  if ( set -e; "$@" ); then
    return 0
  fi
  warn "Etapa '$step_name' falhou — continuando com as próximas etapas"
  FAILED_STEPS+=("$step_name")
  return 0
}
