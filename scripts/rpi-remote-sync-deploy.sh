#!/usr/bin/env bash
set -euo pipefail

# This script runs on the Raspberry Pi inside the rpiai repository.
# Args: [branch] [log_lines] [status_only] [full_reset]

BRANCH="${1:-main}"
LOG_LINES="${2:-120}"
STATUS_ONLY="${3:-0}"
FULL_RESET="${4:-1}"

echo "==> Remote repo: $(pwd)"
echo "==> Branch: $(git rev-parse --abbrev-ref HEAD)"
echo "==> Commit: $(git rev-parse --short HEAD)"
echo "==> Remote status:"
git status --short || true

if [[ "$STATUS_ONLY" == "1" ]]; then
  exit 0
fi

if [[ ! -f .env ]]; then
  echo "Missing .env in repo root" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source ./.env
set +a

required=(
  SAMATHA_DEFAULT_MODEL
  MCP_HOMEY_BASE_URL
  MCP_HOMEY_BEARER_TOKEN
  MCP_HA1_NAME
  MCP_HA1_URL
  MCP_HA1_TOKEN
  MCP_HA2_NAME
  MCP_HA2_URL
  MCP_HA2_TOKEN
)

for key in "${required[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required .env key: $key" >&2
    exit 1
  fi
done

echo "==> Generate automation MCP config from .env"
cat > automation-mcp-server/config.yaml <<YAML
homey:
  enabled: ${MCP_HOMEY_ENABLED:-true}
  base_url: ${MCP_HOMEY_BASE_URL}
  bearer_token: ${MCP_HOMEY_BEARER_TOKEN}
  timeout_seconds: 15

homeassistant:
  instances:
    ${MCP_HA1_NAME}:
      url: ${MCP_HA1_URL}
      token: ${MCP_HA1_TOKEN}
      timeout_seconds: 15
    ${MCP_HA2_NAME}:
      url: ${MCP_HA2_URL}
      token: ${MCP_HA2_TOKEN}
      timeout_seconds: 15

monitor:
  enabled: ${MCP_MONITOR_ENABLED:-true}
  base_url: ${MCP_MONITOR_BASE_URL:-http://rpi-monitor:61208/api/4}
  timeout_seconds: 5

jwt:
  enabled: ${MCP_JWT_ENABLED:-false}
  secret_key: ${MCP_JWT_SECRET_KEY:-CHANGE_ME_JWT_SECRET}
  algorithm: ${MCP_JWT_ALGORITHM:-HS256}
  audience: null
  issuer: null

server:
  host: 0.0.0.0
  port: 8080
YAML

echo "==> Validate compose"
docker compose config >/dev/null

echo "==> Stop current stack"
docker compose down --remove-orphans || true

if [[ "$FULL_RESET" == "1" ]]; then
  echo "==> Full Docker container reset"
  docker ps -aq | xargs -r docker rm -f
fi

echo "==> Pull images"
docker compose pull

echo "==> Start stack"
docker compose up -d --build

echo "==> Wait for health"
deadline=$((SECONDS + 360))
while [[ $SECONDS -lt $deadline ]]; do
  unhealthy="$(docker compose ps --format json | python3 -c 'import json,sys; data=[json.loads(l) for l in sys.stdin if l.strip()]; bad=[d for d in data if d.get("Health") not in ("healthy", "")]; print(len(bad))')"
  if [[ "$unhealthy" == "0" ]]; then
    break
  fi
  sleep 5
done

echo "==> Validate model + services"
docker compose exec -T ollama ollama list | grep -q "${SAMATHA_DEFAULT_MODEL}"
docker compose exec -T ollama ollama list | grep -q "${SAMANTHA_MODEL_NAME:-samantha}"
docker compose exec -T automation-mcp-server python - <<'PY'
import urllib.request

assert urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=5).status == 200
print('mcp-health-ok')
PY

curl -kfsS "https://127.0.0.1:${OPEN_WEBUI_PORT:-3000}/_app/version.json" >/dev/null

echo "==> Compose status"
docker compose ps

echo "==> Logs (tail=$LOG_LINES)"
docker compose logs --tail="$LOG_LINES" samatha-ai stack-ops automation-mcp-server caddy
