#!/usr/bin/env bash
set -euo pipefail

# Run this script from LOCAL Git Bash on Windows.
# It connects to the Raspberry Pi, syncs repo from git, and runs remote deploy logic.
#
# Usage:
#   ./scripts/rpi-sync-deploy-samatha.sh [--status-only] [--force-sync] [pi_user] [pi_host] [branch] [remote_repo_dir] [log_lines]
#
# Examples:
#   ./scripts/rpi-sync-deploy-samatha.sh
#   ./scripts/rpi-sync-deploy-samatha.sh --status-only
#   ./scripts/rpi-sync-deploy-samatha.sh pi rpiai.local main /home/pi/rpiai 120

STATUS_ONLY=0
FORCE_SYNC=0
if [[ "${1:-}" == "--status-only" ]]; then
  STATUS_ONLY=1
  shift
fi
if [[ "${1:-}" == "--force-sync" ]]; then
  FORCE_SYNC=1
  shift
fi

PI_USER="${1:-pi}"
PI_HOST="${2:-rpiai.local}"
BRANCH="${3:-main}"
REMOTE_REPO_DIR="${4:-/home/$PI_USER/rpiai}"
LOG_LINES="${5:-120}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONNECT_SCRIPT="$REPO_ROOT/connect-rpiai.sh"

if [[ ! -x "$CONNECT_SCRIPT" ]]; then
  echo "Error: connect script not executable: $CONNECT_SCRIPT"
  exit 1
fi

echo "==> Local branch: $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
echo "==> Local commit: $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
echo "==> Local status:"
git -C "$REPO_ROOT" status --short || true

if [[ "$STATUS_ONLY" == "1" ]]; then
  REMOTE_CMD="set -euo pipefail; cd $REMOTE_REPO_DIR; git fetch origin; git checkout $BRANCH; git pull --ff-only origin $BRANCH; echo '==> Remote repo:' \$(pwd); echo '==> Branch:' \$(git rev-parse --abbrev-ref HEAD); echo '==> Commit:' \$(git rev-parse --short HEAD); echo '==> Remote status:'; git status --short || true"
else
  if [[ "$FORCE_SYNC" == "1" ]]; then
    REMOTE_CMD="set -euo pipefail; cd $REMOTE_REPO_DIR; git fetch origin; git checkout $BRANCH; git reset --hard origin/$BRANCH; git clean -fd; if [ -x ./scripts/rpi-remote-sync-deploy.sh ]; then bash ./scripts/rpi-remote-sync-deploy.sh $BRANCH $LOG_LINES $STATUS_ONLY; else touch .env; grep -q '^SAMATHA_CONTAINER_API_BASE_URL=' .env && sed -i 's|^SAMATHA_CONTAINER_API_BASE_URL=.*|SAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1|' .env || printf '\nSAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1\n' >> .env; grep -q '^SAMATHA_OLLAMA_BASE_URL=' .env && sed -i 's|^SAMATHA_OLLAMA_BASE_URL=.*|SAMATHA_OLLAMA_BASE_URL=http://ollama:11434|' .env || printf 'SAMATHA_OLLAMA_BASE_URL=http://ollama:11434\n' >> .env; grep -q '^SAMATHA_CONTAINER_API_KEY=' .env && sed -i 's|^SAMATHA_CONTAINER_API_KEY=.*|SAMATHA_CONTAINER_API_KEY=ollama|' .env || printf 'SAMATHA_CONTAINER_API_KEY=ollama\n' >> .env; grep -q '^SAMATHA_DEFAULT_MODEL=' .env && sed -i 's|^SAMATHA_DEFAULT_MODEL=.*|SAMATHA_DEFAULT_MODEL=tinyllama|' .env || printf 'SAMATHA_DEFAULT_MODEL=tinyllama\n' >> .env; grep -q '^SAMATHA_BASE_URL=' .env && sed -i 's|^SAMATHA_BASE_URL=.*|SAMATHA_BASE_URL=http://samatha-ai:8080|' .env || printf 'SAMATHA_BASE_URL=http://samatha-ai:8080\n' >> .env; grep -q '^SAMATHA_OPENAI_API_BASE_URL=' .env || printf 'SAMATHA_OPENAI_API_BASE_URL=https://api.openai.com/v1\n' >> .env; grep -q '^SAMATHA_OPENAI_API_KEY=' .env || printf 'SAMATHA_OPENAI_API_KEY=\n' >> .env; docker compose pull; docker compose up -d --build; for i in \\$(seq 1 30); do docker compose exec -T ollama ollama list >/dev/null 2>&1 && break; sleep 2; done; docker compose exec -T ollama ollama pull \"\\${SAMATHA_DEFAULT_MODEL:-tinyllama}\"; docker compose ps; docker compose logs --tail=$LOG_LINES samatha-ai; fi"
  else
    REMOTE_CMD="set -euo pipefail; cd $REMOTE_REPO_DIR; git fetch origin; git checkout $BRANCH; git pull --ff-only origin $BRANCH; if [ -x ./scripts/rpi-remote-sync-deploy.sh ]; then bash ./scripts/rpi-remote-sync-deploy.sh $BRANCH $LOG_LINES $STATUS_ONLY; else touch .env; grep -q '^SAMATHA_CONTAINER_API_BASE_URL=' .env && sed -i 's|^SAMATHA_CONTAINER_API_BASE_URL=.*|SAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1|' .env || printf '\nSAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1\n' >> .env; grep -q '^SAMATHA_OLLAMA_BASE_URL=' .env && sed -i 's|^SAMATHA_OLLAMA_BASE_URL=.*|SAMATHA_OLLAMA_BASE_URL=http://ollama:11434|' .env || printf 'SAMATHA_OLLAMA_BASE_URL=http://ollama:11434\n' >> .env; grep -q '^SAMATHA_CONTAINER_API_KEY=' .env && sed -i 's|^SAMATHA_CONTAINER_API_KEY=.*|SAMATHA_CONTAINER_API_KEY=ollama|' .env || printf 'SAMATHA_CONTAINER_API_KEY=ollama\n' >> .env; grep -q '^SAMATHA_DEFAULT_MODEL=' .env && sed -i 's|^SAMATHA_DEFAULT_MODEL=.*|SAMATHA_DEFAULT_MODEL=tinyllama|' .env || printf 'SAMATHA_DEFAULT_MODEL=tinyllama\n' >> .env; grep -q '^SAMATHA_BASE_URL=' .env && sed -i 's|^SAMATHA_BASE_URL=.*|SAMATHA_BASE_URL=http://samatha-ai:8080|' .env || printf 'SAMATHA_BASE_URL=http://samatha-ai:8080\n' >> .env; grep -q '^SAMATHA_OPENAI_API_BASE_URL=' .env || printf 'SAMATHA_OPENAI_API_BASE_URL=https://api.openai.com/v1\n' >> .env; grep -q '^SAMATHA_OPENAI_API_KEY=' .env || printf 'SAMATHA_OPENAI_API_KEY=\n' >> .env; docker compose pull; docker compose up -d --build; for i in \$(seq 1 30); do docker compose exec -T ollama ollama list >/dev/null 2>&1 && break; sleep 2; done; docker compose exec -T ollama ollama pull "\${SAMATHA_DEFAULT_MODEL:-tinyllama}"; docker compose ps; docker compose logs --tail=$LOG_LINES samatha-ai; fi"
  fi
fi

echo "==> Running on $PI_USER@$PI_HOST via Git Bash"
REMOTE_CMD="$REMOTE_CMD" "$CONNECT_SCRIPT" "$PI_USER" "$PI_HOST"

echo
if [[ "$STATUS_ONLY" == "1" ]]; then
  echo "Done. Status check completed."
else
  echo "Done. Samatha should be available at: http://$PI_HOST:3000"
fi
