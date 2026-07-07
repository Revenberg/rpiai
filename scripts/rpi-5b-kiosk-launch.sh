#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://localhost:3001}"
CHECK_URL="${CHECK_URL:-$URL}"
LOG_FILE="${HOME:-/home/pi}/kiosk-launch.log"
DISPLAY="${DISPLAY:-:0}"
XAUTHORITY="${XAUTHORITY:-${HOME:-/home/pi}/.Xauthority}"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*" | tee -a "$LOG_FILE"
}

if command -v chromium-browser >/dev/null 2>&1; then
  CHROMIUM_BIN="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
  CHROMIUM_BIN="chromium"
else
  log "Error: chromium is not installed."
  exit 1
fi

export DISPLAY
export XAUTHORITY

# Wait until the graphical server for this user is ready.
for _ in $(seq 1 60); do
  if command -v xdpyinfo >/dev/null 2>&1; then
    if xdpyinfo >/dev/null 2>&1; then
      break
    fi
  else
    # If xdpyinfo is unavailable, proceed and let Chromium decide.
    break
  fi
  sleep 1
done

log "Starting kiosk loop with $CHROMIUM_BIN on DISPLAY=$DISPLAY URL=$URL"

# Keep kiosk running if Chromium exits unexpectedly.
while true; do
  # Avoid opening Chromium on an unreachable endpoint after boot.
  READY=0
  for _ in $(seq 1 120); do
    if command -v curl >/dev/null 2>&1; then
      if curl -fsS "$CHECK_URL" >/dev/null 2>&1; then
        READY=1
        break
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -qO- "$CHECK_URL" >/dev/null 2>&1; then
        READY=1
        break
      fi
    fi
    sleep 1
  done

  if [[ "$READY" -ne 1 ]]; then
    log "Service on $CHECK_URL not ready after 120s; retrying launcher loop"
    sleep 2
    continue
  fi

  pkill -f 'chromium.*--kiosk' >/dev/null 2>&1 || true

  "$CHROMIUM_BIN" \
    --kiosk \
    --no-first-run \
    --use-fake-ui-for-media-stream \
    --autoplay-policy=no-user-gesture-required \
    --disable-gpu \
    --noerrdialogs \
    --disable-infobars \
    --disable-session-crashed-bubble \
    --check-for-update-interval=31536000 \
    "$URL" >>"$LOG_FILE" 2>&1 || true

  log "Chromium exited; restarting in 2s"
  sleep 2
done
