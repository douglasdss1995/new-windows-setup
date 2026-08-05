#!/usr/bin/env bash
# summary.sh — Final summary and next steps

provision_summary() {
  echo ""
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  Provisioning complete!${NC}"
  echo -e "${GREEN}============================================${NC}"
  echo ""
  echo "Next steps:"
  local STEP=1
  echo "  $STEP. Restart terminal or run: exec zsh"; STEP=$((STEP + 1))
  if [ -z "$GIT_USERNAME" ] || [ -z "$GIT_EMAIL" ]; then
    echo "  $STEP. Configure Git identity (or set Git.UserName/UserEmail in windows.config.psd1 and re-run setup-wsl.ps1):"; STEP=$((STEP + 1))
    [ -z "$GIT_USERNAME" ] && echo "       git config --file ~/.gitconfig.local user.name 'Your Name'"
    [ -z "$GIT_EMAIL" ]    && echo "       git config --file ~/.gitconfig.local user.email 'your@email.com'"
  fi
  echo "  $STEP. Authenticate with GitHub: gh auth login"; STEP=$((STEP + 1))
  if [ "$SKIP_DOCKER" = false ]; then
    echo "  $STEP. For Docker without sudo: restart WSL session (wsl --shutdown in PowerShell)"; STEP=$((STEP + 1))
    if [ -n "${ENABLED_PROVIDERS:-}" ]; then
      echo "  $STEP. Start providers:  pvup   (or: cd ~/providers && docker compose up -d)"; STEP=$((STEP + 1))
      [ "$SKIP_POSTGRES"  = false ] && echo "     - PostgreSQL:     localhost:5433"
      [ "$SKIP_REDIS"     = false ] && echo "     - Redis:          localhost:6379"
      [ "$SKIP_PGADMIN"   = false ] && echo "     - pgAdmin:        http://localhost:5050  (admin@admin.com / admin)"
      [ "$SKIP_MINIO"     = false ] && echo "     - MinIO API:      http://localhost:9000"
      [ "$SKIP_MINIO"     = false ] && echo "     - MinIO Console:  http://localhost:9001  (minioadmin / minioadmin)"
      [ "$SKIP_PORTAINER" = false ] && echo "     - Portainer:      http://localhost:8001"
    fi
  fi
  echo ""
}
