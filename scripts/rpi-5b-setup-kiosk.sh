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

ensure_line() {
  local file="$1"
  local line="$2"
  grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

echo "==> Install kiosk dependencies"
sudo apt-get update
sudo apt-get install -y unclutter

if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  sudo apt-get install -y chromium-browser || sudo apt-get install -y chromium
fi

KIOSK_CMD="bash $REPO_ROOT/scripts/rpi-5b-kiosk-launch.sh $KIOSK_URL"

echo "==> Prepare LXDE autostart"
AUTOSTART_DIR="$USER_HOME/.config/lxsession/LXDE-pi"
AUTOSTART_FILE="$AUTOSTART_DIR/autostart"
mkdir -p "$AUTOSTART_DIR"
touch "$AUTOSTART_FILE"

ensure_line "$AUTOSTART_FILE" "@xset s off"
ensure_line "$AUTOSTART_FILE" "@xset -dpms"
ensure_line "$AUTOSTART_FILE" "@xset s noblank"
ensure_line "$AUTOSTART_FILE" "@unclutter -idle 0.5 -root"

if grep -q "rpi-5b-kiosk-launch.sh" "$AUTOSTART_FILE"; then
  sed -i "s|^@bash .*rpi-5b-kiosk-launch\\.sh.*$|@$KIOSK_CMD|" "$AUTOSTART_FILE"
else
  echo "@$KIOSK_CMD" >> "$AUTOSTART_FILE"
fi

echo "==> Prepare Wayfire autostart"
WAYFIRE_FILE="$USER_HOME/.config/wayfire.ini"
mkdir -p "$(dirname "$WAYFIRE_FILE")"
touch "$WAYFIRE_FILE"

if ! grep -q "^\[autostart\]$" "$WAYFIRE_FILE"; then
  printf "\n[autostart]\n" >> "$WAYFIRE_FILE"
fi

if grep -q "^kiosk = " "$WAYFIRE_FILE"; then
  sed -i "s|^kiosk = .*|kiosk = $KIOSK_CMD|" "$WAYFIRE_FILE"
else
  awk -v line="kiosk = $KIOSK_CMD" '
    BEGIN {added=0}
    /^\[autostart\]$/ {print; if (!added) {print line; added=1; next}}
    {print}
    END {if (!added) {print "[autostart]"; print line}}
  ' "$WAYFIRE_FILE" > "$WAYFIRE_FILE.tmp"
  mv "$WAYFIRE_FILE.tmp" "$WAYFIRE_FILE"
fi

echo "==> Prepare Labwc autostart"
LABWC_DIR="$USER_HOME/.config/labwc"
LABWC_FILE="$LABWC_DIR/autostart"
mkdir -p "$LABWC_DIR"
touch "$LABWC_FILE"

if grep -q "rpi-5b-kiosk-launch.sh" "$LABWC_FILE"; then
  sed -i "s|^.*rpi-5b-kiosk-launch\\.sh.*$|$KIOSK_CMD \&|" "$LABWC_FILE"
else
  echo "$KIOSK_CMD &" >> "$LABWC_FILE"
fi

sudo chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.config"

echo "==> Kiosk autostart configured"
echo "LXDE autostart: $AUTOSTART_FILE"
echo "Wayfire config: $WAYFIRE_FILE"
echo "Labwc autostart: $LABWC_FILE"
echo "URL: $KIOSK_URL"
echo "Next: reboot or log out/in on the Pi desktop session."
