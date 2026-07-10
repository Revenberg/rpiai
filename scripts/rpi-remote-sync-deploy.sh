#!/usr/bin/env bash
set -euo pipefail

# This script runs on the Raspberry Pi inside the rpiai repository.
# Args: [branch] [log_lines] [status_only]

BRANCH="${1:-main}"
LOG_LINES="${2:-120}"
STATUS_ONLY="${3:-0}"

echo "==> Remote repo: $(pwd)"
echo "==> Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "==> Commit: $(git rev-parse --short HEAD)"
echo "==> Remote status:"
git status --short || true

if [[ "$STATUS_ONLY" == "1" ]]; then
  exit 0
fi

# Enforce Samatha config: local container first, OpenAI fallback.
touch .env

if grep -q '^SAMATHA_CONTAINER_API_BASE_URL=' .env; then
  sed -i 's|^SAMATHA_CONTAINER_API_BASE_URL=.*|SAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1|' .env
else
  printf '\nSAMATHA_CONTAINER_API_BASE_URL=http://ollama:11434/v1\n' >> .env
fi

if grep -q '^SAMATHA_OLLAMA_BASE_URL=' .env; then
  sed -i 's|^SAMATHA_OLLAMA_BASE_URL=.*|SAMATHA_OLLAMA_BASE_URL=http://ollama:11434|' .env
else
  printf 'SAMATHA_OLLAMA_BASE_URL=http://ollama:11434\n' >> .env
fi

if grep -q '^SAMATHA_CONTAINER_API_KEY=' .env; then
  sed -i 's|^SAMATHA_CONTAINER_API_KEY=.*|SAMATHA_CONTAINER_API_KEY=ollama|' .env
else
  printf 'SAMATHA_CONTAINER_API_KEY=ollama\n' >> .env
fi

if grep -q '^SAMATHA_DEFAULT_MODEL=' .env; then
  sed -i 's|^SAMATHA_DEFAULT_MODEL=.*|SAMATHA_DEFAULT_MODEL=tinyllama|' .env
else
  printf 'SAMATHA_DEFAULT_MODEL=tinyllama\n' >> .env
fi

if grep -q '^SAMATHA_BASE_URL=' .env; then
  sed -i 's|^SAMATHA_BASE_URL=.*|SAMATHA_BASE_URL=http://samatha-ai:8080|' .env
else
  printf 'SAMATHA_BASE_URL=http://samatha-ai:8080\n' >> .env
fi

if ! grep -q '^SAMATHA_OPENAI_API_BASE_URL=' .env; then
  printf 'SAMATHA_OPENAI_API_BASE_URL=https://api.openai.com/v1\n' >> .env
fi

if ! grep -q '^SAMATHA_OPENAI_API_KEY=' .env; then
  printf 'SAMATHA_OPENAI_API_KEY=\n' >> .env
fi

echo "==> Pull images"
docker compose pull

echo "==> Up services"
docker compose up -d --build

echo "==> Ensure Ollama model is available (tinyllama)"
for i in $(seq 1 30); do
  if docker compose exec -T ollama ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
docker compose exec -T ollama ollama pull "${SAMATHA_DEFAULT_MODEL:-tinyllama}"

echo "==> Compose status"
docker compose ps

echo "==> Samatha logs (tail=$LOG_LINES)"
docker compose logs --tail="$LOG_LINES" samatha-ai
