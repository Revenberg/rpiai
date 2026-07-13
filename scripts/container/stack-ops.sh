#!/bin/sh
set -eu

STATE_DIR="/state"
mkdir -p "$STATE_DIR"

OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://ollama:11434}"
OPENWEBUI_BASE_URL="${OPENWEBUI_BASE_URL:-http://samatha-ai:8080}"
MCP_BASE_URL="${MCP_BASE_URL:-http://automation-mcp-server:8080}"
DEFAULT_MODEL="${DEFAULT_MODEL:-qwen2.5:0.5b}"
SAMANTHA_MODEL_NAME="${SAMANTHA_MODEL_NAME:-samantha}"
OPS_LOOP_SECONDS="${OPS_LOOP_SECONDS:-300}"
REQUIRE_HTTPS_CHECK="${REQUIRE_HTTPS_CHECK:-false}"
CADDY_PUBLIC_URL="${CADDY_PUBLIC_URL:-https://localhost:3000}"

http_get() {
  wget -q -T 10 -O - "$1"
}

http_post_json() {
  url="$1"
  body="$2"
  wget -q -T 60 -O - \
    --header="Content-Type: application/json" \
    --post-data="$body" \
    "$url"
}

write_network_snapshot() {
  {
    echo "timestamp=$(date -Iseconds)"
    echo "hostname=$(hostname)"
    echo "host_ip=$(hostname -i 2>/dev/null || true)"
    echo "routes:"
    cat /proc/net/route 2>/dev/null || true
  } >"$STATE_DIR/network.txt"
}

validate_mcp_config() {
  cfg="/src/mcp/config.yaml"
  [ -f "$cfg" ] || return 1
  grep -q "^homey:" "$cfg"
  grep -q "home_assistant_1:" "$cfg"
  grep -q "home_assistant_2:" "$cfg"
}

ensure_qwen_model() {
  http_post_json "$OLLAMA_BASE_URL/api/pull" "{\"name\":\"$DEFAULT_MODEL\",\"stream\":false}" >/dev/null
}

ensure_samantha_model() {
  tags="$(http_get "$OLLAMA_BASE_URL/api/tags" || true)"
  echo "$tags" | grep -q "\"name\":\"$SAMANTHA_MODEL_NAME" && return 0

  # Create a Samantha alias model on top of qwen.
  http_post_json "$OLLAMA_BASE_URL/api/create" "{\"name\":\"$SAMANTHA_MODEL_NAME\",\"modelfile\":\"FROM $DEFAULT_MODEL\\nSYSTEM You are Samantha, a concise Dutch-speaking home assistant.\\nPARAMETER temperature 0.3\\n\",\"stream\":false}" >/dev/null
}

initialize_openwebui() {
  http_get "$OPENWEBUI_BASE_URL/_app/version.json" >/dev/null
  http_get "$OPENWEBUI_BASE_URL/api/version" >/dev/null
}

run_validation() {
  validate_mcp_config
  http_get "$MCP_BASE_URL/health" | grep -q '"status":"ok"'

  tags="$(http_get "$OLLAMA_BASE_URL/api/tags")"
  echo "$tags" | grep -q "$DEFAULT_MODEL"
  echo "$tags" | grep -q "$SAMANTHA_MODEL_NAME"

  if [ "$REQUIRE_HTTPS_CHECK" = "true" ]; then
    wget -q --no-check-certificate -T 10 -O - "$CADDY_PUBLIC_URL" >/dev/null
  fi
}

while true; do
  write_network_snapshot || true
  ensure_qwen_model
  ensure_samantha_model
  initialize_openwebui
  run_validation
  date -Iseconds >"$STATE_DIR/last_success"
  sleep "$OPS_LOOP_SECONDS"
done
