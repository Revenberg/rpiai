#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "==> Container status"
docker compose ps samatha-ai

echo "==> Health status"
CONTAINER_ID="$(docker compose ps -q samatha-ai)"
if [[ -n "$CONTAINER_ID" ]]; then
  docker inspect --format='{{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER_ID"
else
  echo "samatha-ai container not found"
  exit 1
fi

echo "==> API check"
if command -v curl >/dev/null 2>&1; then
  curl -fsS http://localhost:3000/api/version
else
  wget -qO- http://localhost:3000/api/version
fi

echo
echo "Verification complete."
