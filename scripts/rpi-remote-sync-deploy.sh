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

echo "==> Enforce persisted Open WebUI Ollama connection"
docker compose exec -T samatha-ai python - <<'PY' || true
import os
import sqlite3

db_path = "/app/backend/data/webui.db"
if not os.path.exists(db_path):
  print("webui.db not found, skipping persisted connection fix")
  raise SystemExit(0)

replacements = [
  ("http://host.docker.internal:11434", "http://ollama:11434"),
  ("host.docker.internal:11434", "ollama:11434"),
]

conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = [row[0] for row in cur.fetchall()]
updated = 0

for table in tables:
  table_q = table.replace('"', '""')
  cur.execute(f'PRAGMA table_info("{table_q}")')
  columns = cur.fetchall()
  for col in columns:
    col_name = col[1]
    col_type = (col[2] or "").upper()
    if col_type not in ("", "TEXT", "VARCHAR", "CHAR", "CLOB"):
      continue

    col_q = col_name.replace('"', '""')
    for source, target in replacements:
      sql = (
        f'UPDATE "{table_q}" '
        f'SET "{col_q}" = REPLACE("{col_q}", ?, ?) '
        f'WHERE "{col_q}" LIKE ?'
      )
      cur.execute(sql, (source, target, f"%{source}%"))
      if cur.rowcount and cur.rowcount > 0:
        updated += cur.rowcount

conn.commit()
conn.close()
print(f"Persisted connection fix updated {updated} row(s)")
PY

echo "==> Recreate Samatha after persisted fix"
docker compose up -d --force-recreate samatha-ai

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
