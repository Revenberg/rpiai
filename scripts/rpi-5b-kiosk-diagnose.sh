#!/usr/bin/env bash
set -euo pipefail

echo "== Host =="
hostname
whoami
echo

echo "== Display sessions =="
loginctl list-sessions --no-legend || true
echo

echo "== Display manager =="
systemctl status display-manager --no-pager --lines=20 || true
echo

echo "== Kiosk autostart files =="
for f in \
  "$HOME/.config/lxsession/LXDE-pi/autostart" \
  "$HOME/.config/wayfire.ini" \
  "$HOME/.config/labwc/autostart"; do
  echo "--- $f ---"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    echo "(missing)"
  fi
  echo
done

echo "== Chromium binary =="
command -v chromium-browser || true
command -v chromium || true
echo

echo "== Running processes =="
pgrep -af "chromium|wayfire|labwc|lxsession|Xorg|Xwayland" || true
echo

echo "== Kiosk launch log =="
if [[ -f "$HOME/kiosk-launch.log" ]]; then
  tail -n 120 "$HOME/kiosk-launch.log"
else
  echo "(missing)"
fi
