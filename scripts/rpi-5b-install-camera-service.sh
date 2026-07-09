#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: this script must run on Linux (Raspberry Pi)."
  exit 1
fi

SERVICE_NAME="rpi-camera-stream.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_SRC="$SCRIPT_DIR/rpi-5b-camera-stream.service"
UNIT_DST="/etc/systemd/system/$SERVICE_NAME"
FLAG_FILE="/home/kiosk/.camera-stream-managed"

if [[ ! -f "$UNIT_SRC" ]]; then
  echo "Error: missing unit file: $UNIT_SRC"
  exit 1
fi

echo "==> Installing $SERVICE_NAME"
sudo install -m 644 "$UNIT_SRC" "$UNIT_DST"
sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"

echo "==> Marking camera stream as externally managed for kiosk launcher"
sudo -u kiosk touch "$FLAG_FILE"

echo "==> Service status"
sudo systemctl --no-pager --full status "$SERVICE_NAME" | sed -n '1,20p'

echo "==> Verifying stream bytes"
timeout 6 curl -sS http://localhost:8081/stream.mjpg -o /tmp/camcheck-service.bin || true
ls -l /tmp/camcheck-service.bin 2>/dev/null || echo "no-stream-bytes"

echo "Done."
