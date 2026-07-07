#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://localhost:3000}"

if command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM_BIN="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
  CHROMIUM_BIN="chromium"
else
  echo "Error: chromium is not installed."
  exit 1
fi

# Keep kiosk running if Chromium exits unexpectedly.
while true; do
  "$CHROMIUM_BIN" \
    --kiosk \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    "$URL"
  sleep 2
done
