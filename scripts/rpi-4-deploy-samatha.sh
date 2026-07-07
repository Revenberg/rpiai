#!/usr/bin/env bash
set -euo pipefail

LOG_LINES="${1:-100}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "$REPO_ROOT/docker-compose.yml" ]]; then
  echo "Error: docker-compose.yml not found in $REPO_ROOT"
  exit 1
fi

echo "==> Pull latest image(s)"
docker compose pull

echo "==> Start services"
docker compose up -d

echo "==> Service status"
docker compose ps

echo "==> Recent Samatha logs (tail=$LOG_LINES)"
docker compose logs --tail="$LOG_LINES" samatha-ai

echo
echo "Samatha deployment completed. Open: http://rpiai.local:3000"
