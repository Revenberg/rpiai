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

# Normalize Windows line endings if present.
sed -i 's/\r$//' .env

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

# Give slower links and ARM devices more headroom for registry operations.
export DOCKER_CLIENT_TIMEOUT="${DOCKER_CLIENT_TIMEOUT:-600}"
export COMPOSE_HTTP_TIMEOUT="${COMPOSE_HTTP_TIMEOUT:-600}"

echo "==> Stop current stack"
docker compose down --remove-orphans || true

if [[ "$FULL_RESET" == "1" ]]; then
  echo "==> Full Docker container reset"
  docker ps -aq | xargs -r docker rm -f
fi

echo "==> Pull images (per-image retries)"
mapfile -t compose_images < <(docker compose config --images | awk 'NF' | sort -u)

if [[ "${#compose_images[@]}" -eq 0 ]]; then
  echo "No images found in compose config" >&2
  exit 1
fi

pull_image_with_retry() {
  local image="$1"
  local attempt
  local delay=12
  local pull_timeout="${DOCKER_PULL_TIMEOUT:-300}"

  for attempt in 1 2 3 4 5 6 7 8; do
    echo "--> Pull ${image} (attempt ${attempt}/8)"
    if command -v timeout >/dev/null 2>&1; then
      if timeout "$pull_timeout" docker pull "${image}"; then
        return 0
      fi
    else
      if docker pull "${image}"; then
        return 0
      fi
    fi

    if [[ "$attempt" -lt 8 ]]; then
      echo "Pull failed for ${image} (attempt ${attempt}), retrying in ${delay}s..."
      sleep "$delay"
      if [[ "$delay" -lt 90 ]]; then
        delay=$((delay * 2))
        if [[ "$delay" -gt 90 ]]; then
          delay=90
        fi
      fi
    fi
  done

  echo "Failed to pull image after retries: ${image}" >&2
  return 1
}

for image in "${compose_images[@]}"; do
  pull_image_with_retry "$image"
done

echo "==> Pull buildable services if needed"
docker compose pull --ignore-buildable || true

echo "==> Start stack"
docker compose up -d --build

echo "==> Wait for core services"
deadline=$((SECONDS + 360))
while [[ $SECONDS -lt $deadline ]]; do
  running_count="$(docker compose ps --services --status running | wc -l | tr -d '[:space:]')"
  if [[ "${running_count:-0}" -ge 6 ]]; then
    break
  fi
  sleep 5
done

echo "==> Ensure Samantha model alias exists"
if ! docker compose exec -T ollama ollama list | grep -q "${SAMANTHA_MODEL_NAME:-samantha}"; then
  docker compose exec -T ollama sh -lc "cat >/tmp/Modelfile.samantha <<'EOF'
FROM ${SAMATHA_DEFAULT_MODEL}
SYSTEM You are Samantha, a concise Dutch-speaking home assistant.
PARAMETER temperature 0.3
EOF
ollama create ${SAMANTHA_MODEL_NAME:-samantha} -f /tmp/Modelfile.samantha"
fi

echo "==> Validate model + services"
docker compose exec -T ollama ollama list | grep -q "${SAMATHA_DEFAULT_MODEL}"
docker compose exec -T ollama ollama list | grep -q "${SAMANTHA_MODEL_NAME:-samantha}"
docker compose exec -T automation-mcp-server python - <<'PY'
import urllib.request

assert urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=5).status == 200
print('mcp-health-ok')
PY

echo "==> Wait for Open WebUI readiness"
for i in $(seq 1 90); do
  if docker compose exec -T samatha-ai sh -lc 'curl -fsS http://127.0.0.1:8080/_app/version.json >/dev/null'; then
    break
  fi
  sleep 4
done

echo "==> Verify Caddy HTTPS endpoint"
for i in $(seq 1 60); do
  if curl -kfsS "https://127.0.0.1:${OPEN_WEBUI_PORT:-3000}/_app/version.json" >/dev/null; then
    break
  fi
  sleep 2
done

curl -kfsS "https://127.0.0.1:${OPEN_WEBUI_PORT:-3000}/_app/version.json" >/dev/null

echo "==> Compose status"
docker compose ps

echo "==> Logs (tail=$LOG_LINES)"
docker compose logs --tail="$LOG_LINES" samatha-ai stack-ops automation-mcp-server caddy
