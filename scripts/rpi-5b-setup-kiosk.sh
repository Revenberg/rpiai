#!/usr/bin/env bash
set -euo pipefail

KIOSK_URL="${1:-http://localhost:3000}"
TARGET_USER="${2:-${SUDO_USER:-$USER}}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: this script must run on Linux (Raspberry Pi)."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
  echo "Error: could not resolve home directory for user '$TARGET_USER'."
  exit 1
fi

echo "==> Install kiosk dependencies"
sudo apt-get update
sudo apt-get install -y unclutter

if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
fi

echo "==> Prepare LXDE autostart"
AUTOSTART_DIR="$USER_HOME/.config/lxsession/LXDE-pi"
AUTOSTART_FILE="$AUTOSTART_DIR/autostart"
mkdir -p "$AUTOSTART_DIR"

# Ensure baseline desktop options are present.
grep -q '^@xset s off$' "$AUTOSTART_FILE" 2>/dev/null || echo '@xset s off' >> "$AUTOSTART_FILE"
grep -q '^@xset -dpms$' "$AUTOSTART_FILE" 2>/dev/null || echo '@xset -dpms' >> "$AUTOSTART_FILE"
grep -q '^@xset s noblank$' "$AUTOSTART_FILE" 2>/dev/null || echo '@xset s noblank' >> "$AUTOSTART_FILE"
grep -q '^@unclutter -idle 0.5 -root$' "$AUTOSTART_FILE" 2>/dev/null || echo '@unclutter -idle 0.5 -root' >> "$AUTOSTART_FILE"

KIOSK_LINE="@bash $REPO_ROOT/scripts/rpi-5b-kiosk-launch.sh $KIOSK_URL"
if grep -q 'rpi-5b-kiosk-launch.sh' "$AUTOSTART_FILE" 2>/dev/null; then
  sed -i "s|^@bash .*rpi-5b-kiosk-launch\.sh.*$|$KIOSK_LINE|" "$AUTOSTART_FILE"
else
  echo "$KIOSK_LINE" >> "$AUTOSTART_FILE"
fi

sudo chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.config"

echo "==> Kiosk autostart configured"
echo "Autostart file: $AUTOSTART_FILE"
echo "URL: $KIOSK_URL"
echo "Next: reboot or log out/in on the Pi desktop session."
