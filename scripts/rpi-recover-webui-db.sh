#!/usr/bin/env bash
set -euo pipefail

cd ~/rpiai

echo "==> Stopping samatha-ai"
docker compose stop samatha-ai

echo "==> Removing Open WebUI DB files from volume"
docker run --rm -v rpiai_samatha_data:/data alpine sh -lc 'rm -f /data/webui.db /data/webui.db-shm /data/webui.db-wal'

echo "==> Starting samatha-ai"
docker compose up -d samatha-ai

echo "==> Waiting for startup"
sleep 25

echo "==> Status"
docker compose ps samatha-ai

echo "==> Version endpoint"
code="$(curl -s -o /tmp/webui_version.json -w '%{http_code}' http://localhost:3000/_app/version.json || true)"
echo "HTTP=$code"
if [ -f /tmp/webui_version.json ]; then
  head -c 220 /tmp/webui_version.json || true
  echo
fi
