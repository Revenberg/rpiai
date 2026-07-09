#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

run_remote() {
  local remote_cmd="$1"
  REMOTE_CMD="$remote_cmd" ./connect-rpiai.sh pi 192.168.1.1
}

echo "=== Connectivity tests from RPi ==="
run_remote "printf 'homey='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 http://homey/api/manager/system; echo"
run_remote "printf 'ha_energie='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 http://192.168.1.123:8123/api/; echo"
run_remote "printf 'ha_aanwezigheid='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 http://192.168.1.80:8123/api/; echo"

echo "=== Auth tests from RPi (using config tokens) ==="
run_remote "cd ~/rpiai/automation-mcp-server && HOMEY_TOKEN=\$(awk -F': ' '/bearer_token:/{print \$2; exit}' config.yaml) && case \"\$HOMEY_TOKEN\" in REPLACE*|LONG_LIVED*|YOUR_*|\"\") echo 'homey_auth=SKIPPED (placeholder/missing token)';; *) printf 'homey_auth='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 -H \"Authorization: Bearer \$HOMEY_TOKEN\" http://homey/api/manager/system; echo;; esac"
run_remote "cd ~/rpiai/automation-mcp-server && HA_EN_TOKEN=\$(awk -F': ' '/energie:/{f=1;next}/aanwezigheid:/{f=0} f&&/token:/{print \$2; exit}' config.yaml) && case \"\$HA_EN_TOKEN\" in REPLACE*|LONG_LIVED*|YOUR_*|\"\") echo 'ha_energie_auth=SKIPPED (placeholder/missing token)';; *) printf 'ha_energie_auth='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 -H \"Authorization: Bearer \$HA_EN_TOKEN\" http://192.168.1.123:8123/api/; echo;; esac"
run_remote "cd ~/rpiai/automation-mcp-server && HA_AAN_TOKEN=\$(awk -F': ' '/aanwezigheid:/{f=1;next} f&&/token:/{print \$2; exit}' config.yaml) && case \"\$HA_AAN_TOKEN\" in REPLACE*|LONG_LIVED*|YOUR_*|\"\") echo 'ha_aanwezigheid_auth=SKIPPED (placeholder/missing token)';; *) printf 'ha_aanwezigheid_auth='; /usr/bin/curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 6 --max-time 10 -H \"Authorization: Bearer \$HA_AAN_TOKEN\" http://192.168.1.80:8123/api/; echo;; esac"
