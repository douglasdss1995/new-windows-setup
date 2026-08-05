#!/usr/bin/env bash
# logging.sh — Logging and output helpers for provision.sh

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
