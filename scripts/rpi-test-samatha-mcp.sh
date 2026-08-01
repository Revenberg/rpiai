#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SAMATHA_BASE_URL="${SAMATHA_BASE_URL:-https://rpiai.local}"
SAMATHA_EMAIL="${SAMATHA_EMAIL:-pi@home.com}"
SAMATHA_PASSWORD="${SAMATHA_PASSWORD:-admin}"
SAMATHA_MODEL="${SAMATHA_MODEL:-qwen2.5:0.5b}"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/automation-mcp-server/config.yaml}"
MAX_ROWS="${MAX_ROWS:-8}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing command '$cmd'" >&2
    exit 1
  fi
}

parse_config_field() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    $0 ~ "^" section ":" {in_section=1; next}
    in_section && $0 ~ "^  " key ":" {
      sub("^  " key ": *", "", $0)
      print $0
      exit
    }
    in_section && /^[^ ]/ {in_section=0}
  ' "$CONFIG_FILE"
}

list_ha_instances() {
  awk '
    /^homeassistant:/ {in_ha=1; next}
    in_ha && /^  instances:/ {in_instances=1; next}
    in_ha && in_instances && /^    [A-Za-z0-9_-]+:/ {
      name=$1
      sub(":", "", name)
      print name
      next
    }
    in_ha && /^[^ ]/ {in_ha=0; in_instances=0}
  ' "$CONFIG_FILE"
}

ha_instance_field() {
  local instance="$1"
  local field="$2"
  awk -v instance="$instance" -v field="$field" '
    /^homeassistant:/ {in_ha=1; next}
    in_ha && /^  instances:/ {in_instances=1; next}
    in_ha && in_instances && $0 ~ "^    " instance ":" {in_target=1; next}
    in_target && $0 ~ "^      " field ":" {
      sub("^      " field ": *", "", $0)
      print $0
      exit
    }
    in_target && /^    [A-Za-z0-9_-]+:/ {in_target=0}
    in_ha && /^[^ ]/ {in_ha=0; in_instances=0; in_target=0}
  ' "$CONFIG_FILE"
}

print_header() {
  echo
  echo "=== $1 ==="
}

cd "$REPO_ROOT"

require_cmd docker
require_cmd curl
require_cmd python3

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
fi

print_header "Container status"
docker compose ps samatha-ai automation-mcp-server

print_header "MCP server health/meta"
curl -fsS "http://127.0.0.1:8090/health" | python3 -m json.tool
curl -fsS "http://127.0.0.1:8090/meta" | python3 -m json.tool

print_header "Samantha API version"
curl -kfsS "$SAMATHA_BASE_URL/api/version" | python3 -m json.tool

print_header "Samantha signin"
SIGNIN_PAYLOAD=$(printf '{"email":"%s","password":"%s"}' "$SAMATHA_EMAIL" "$SAMATHA_PASSWORD")
SIGNIN_JSON=$(curl -kfsS -X POST "$SAMATHA_BASE_URL/api/v1/auths/signin" -H "Content-Type: application/json" -d "$SIGNIN_PAYLOAD")
SAMATHA_TOKEN=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("token",""))' <<<"$SIGNIN_JSON")

if [[ -z "$SAMATHA_TOKEN" ]]; then
  echo "ERROR: signin succeeded but no token returned" >&2
  exit 1
fi
echo "OK: token received (length ${#SAMATHA_TOKEN})"

HA_INSTANCES=()
while IFS= read -r name; do
  [[ -n "$name" ]] && HA_INSTANCES+=("$name")
done < <(list_ha_instances)

PROMPT="Gebruik MCP tools homey.devices en ha.states voor alle Home Assistant instances. Geef de status en namen van maximaal 3 belangrijke apparaten per platform in tabelvorm: platform, naam, status, details, timestamp."
if [[ ${#HA_INSTANCES[@]} -gt 0 ]]; then
  PROMPT+=" Home Assistant instances: ${HA_INSTANCES[*]}."
fi

print_header "Samantha -> toolgerichte prompt (MCP test)"
CHAT_JSON=$(python3 - <<PY
import json
model = ${SAMATHA_MODEL@Q}
prompt = ${PROMPT@Q}
print(json.dumps({
    "model": model,
    "messages": [{"role": "user", "content": prompt}],
    "stream": False
}))
PY
)

CHAT_RESPONSE=$(curl -kfsS -X POST "$SAMATHA_BASE_URL/jarvis/api/chat/completions" -H "Content-Type: application/json" -d "$CHAT_JSON")
python3 -c 'import json,sys
obj=json.load(sys.stdin)
msg=""
try:
  msg=obj.get("choices", [{}])[0].get("message", {}).get("content", "")
except Exception:
  msg=""
print(msg if msg else json.dumps(obj, indent=2, ensure_ascii=False))' <<<"$CHAT_RESPONSE"

print_header "automation-mcp-server logs (laatste 2 minuten, tool calls)"
docker compose logs --since 2m automation-mcp-server | grep -E 'homey\.|ha\.' || echo "Geen expliciete tool-call regels gevonden in dit interval."

HOMEY_URL="$(parse_config_field "homey" "base_url" || true)"
HOMEY_TOKEN="$(parse_config_field "homey" "bearer_token" || true)"

print_header "Homey devices (direct check)"
if [[ -z "$HOMEY_URL" || -z "$HOMEY_TOKEN" || "$HOMEY_TOKEN" == CHANGE_ME* ]]; then
  echo "SKIP: Homey base_url/token ontbreekt of is placeholder in $CONFIG_FILE"
else
  HOMEY_JSON=$(curl -fsS -H "Authorization: Bearer $HOMEY_TOKEN" "$HOMEY_URL/api/manager/devices/device")
  python3 -c 'import json,sys
limit=int(sys.argv[1])
data=json.load(sys.stdin)
items=data.values() if isinstance(data, dict) else []
rows=[]
for d in items:
  if not isinstance(d, dict):
    continue
  name=d.get("name") or d.get("id") or "unknown"
  status="online" if d.get("available", True) else "offline"
  details=d.get("class") or d.get("driverId") or "-"
  rows.append((name, status, details))
rows.sort(key=lambda x: x[0].lower())
print(f"HOMEY devices shown: {min(len(rows), limit)} / {len(rows)}")
for name, status, details in rows[:limit]:
  print(f"- {name} | {status} | {details}")' "$MAX_ROWS" <<<"$HOMEY_JSON"
fi

print_header "Home Assistant devices/states (direct check)"
if [[ ${#HA_INSTANCES[@]} -eq 0 ]]; then
  echo "SKIP: geen Home Assistant instances gevonden in $CONFIG_FILE"
else
  for inst in "${HA_INSTANCES[@]}"; do
    HA_URL="$(ha_instance_field "$inst" "url" || true)"
    HA_TOKEN="$(ha_instance_field "$inst" "token" || true)"

    echo "instance=$inst"
    if [[ -z "$HA_URL" || -z "$HA_TOKEN" || "$HA_TOKEN" == CHANGE_ME* ]]; then
      echo "  SKIP: url/token ontbreekt of placeholder"
      continue
    fi

    HA_STATES=$(curl -fsS -H "Authorization: Bearer $HA_TOKEN" "$HA_URL/api/states")
    python3 -c 'import json,sys
  limit=int(sys.argv[1])
  states=json.load(sys.stdin)
  preferred={"light","switch","climate","cover","sensor","binary_sensor"}
  rows=[]
  for item in states:
    eid=item.get("entity_id", "")
    if "." not in eid:
      continue
    domain,_=eid.split(".", 1)
    if domain not in preferred:
      continue
    attrs=item.get("attributes") or {}
    name=attrs.get("friendly_name") or eid
    rows.append((name, item.get("state", "unknown"), eid))
  rows.sort(key=lambda x: x[0].lower())
  print(f"  HA entities shown: {min(len(rows), limit)} / {len(rows)}")
  for name, state, eid in rows[:limit]:
    print(f"  - {name} | {state} | {eid}")' "$MAX_ROWS" <<<"$HA_STATES"
  done
fi

echo
echo "Klaar. Deze test controleert Samantha + MCP connectie en toont Homey/HA device status met namen."