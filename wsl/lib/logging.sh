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
  # still stops that step immediately (fail-fast within the step). errexit is
  # ignored anywhere inside an `if`/`||` condition, so the subshell must NOT be
  # one: disable errexit around it instead, capture the status, and restore.
  local rc restore_errexit=false
  case $- in *e*) restore_errexit=true ;; esac
  set +e
  ( set -e; "$@" )
  rc=$?
  [ "$restore_errexit" = true ] && set -e
  if [ "$rc" -eq 0 ]; then
    return 0
  fi
  warn "Etapa '$step_name' falhou — continuando com as próximas etapas"
  FAILED_STEPS+=("$step_name")
  return 0
}
