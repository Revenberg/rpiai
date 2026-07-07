#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./connect-rpiai.sh [pi_user] [pi_host] [remote_command]
# Environment overrides:
#   PI_USER, PI_HOST, PASSWORD_FILE, REMOTE_CMD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PASSWORD_FILE="$SCRIPT_DIR/../rpiai.password"
PASSWORD_FILE="${PASSWORD_FILE:-$DEFAULT_PASSWORD_FILE}"
PI_USER="${PI_USER:-${1:-pi}}"
PI_HOST="${PI_HOST:-${2:-rpiai.local}}"
if [[ -n "${REMOTE_CMD:-}" ]]; then
  REMOTE_CMD="$REMOTE_CMD"
elif [[ $# -ge 3 ]]; then
  REMOTE_CMD="${*:3}"
else
  REMOTE_CMD=""
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "Error: ssh is not installed or not in PATH."
  exit 1
fi

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
WIN_USER="${USERNAME:-${USER:-}}"

SSHPASS_BIN=""
if command -v sshpass >/dev/null 2>&1; then
  SSHPASS_BIN="sshpass"
else
  # Windows fallback locations for winget-installed sshpass.
  if [[ -n "$WIN_USER" && -x "/c/Users/$WIN_USER/AppData/Local/Microsoft/WinGet/Links/sshpass.exe" ]]; then
    SSHPASS_BIN="/c/Users/$WIN_USER/AppData/Local/Microsoft/WinGet/Links/sshpass.exe"
  else
    MATCHED_SSHPASS=""
    if [[ -n "$WIN_USER" ]]; then
      MATCHED_SSHPASS="$(compgen -G "/c/Users/$WIN_USER/AppData/Local/Microsoft/WinGet/Packages/xhcoding.sshpass-win32*/sshpass.exe" | head -n 1 || true)"
    fi
    if [[ -n "$MATCHED_SSHPASS" ]]; then
      SSHPASS_BIN="$MATCHED_SSHPASS"
    fi
  fi
fi

PASSWORD=""
USE_SSHPASS=0
if [[ -n "$SSHPASS_BIN" && -f "$PASSWORD_FILE" ]]; then
  PASSWORD="$(<"$PASSWORD_FILE")"
  # Trim common trailing newline/CRLF from password file.
  PASSWORD="${PASSWORD%$'\r'}"
  PASSWORD="${PASSWORD%$'\n'}"
  if [[ -n "$PASSWORD" ]]; then
    USE_SSHPASS=1
  fi
fi

run_ssh() {
  if [[ "$USE_SSHPASS" -eq 1 ]]; then
    "$SSHPASS_BIN" -p "$PASSWORD" ssh "${SSH_OPTS[@]}" "$@"
  else
    ssh "${SSH_OPTS[@]}" "$@"
  fi
}

if [[ -n "$REMOTE_CMD" ]]; then
  echo "Running remote command on $PI_USER@$PI_HOST: $REMOTE_CMD"
  run_ssh "$PI_USER@$PI_HOST" "$REMOTE_CMD"
  exit $?
fi

echo "Connecting interactively to $PI_USER@$PI_HOST ..."
# Force pseudo-terminal allocation so prompt appears even when launched from PowerShell.
run_ssh -tt "$PI_USER@$PI_HOST"
