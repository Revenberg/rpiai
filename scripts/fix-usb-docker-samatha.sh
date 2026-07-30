#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/fix-usb-docker-samatha.sh [pi_user] [pi_host]
# Env:
#   PASSWORD_FILE (default: ../rpiai.password)

PI_USER="${1:-pi}"
PI_HOST="${2:-rpiai.local}"
PASSWORD_FILE="${PASSWORD_FILE:-../rpiai.password}"

if ! command -v ssh >/dev/null 2>&1; then
  echo "Error: ssh not found in PATH"
  exit 1
fi

SSHPASS_BIN=""
if command -v sshpass >/dev/null 2>&1; then
  SSHPASS_BIN="sshpass"
elif [[ -x "/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Links/sshpass.exe" ]]; then
  SSHPASS_BIN="/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Links/sshpass.exe"
else
  MATCHED_SSHPASS="$(compgen -G "/c/Users/$USERNAME/AppData/Local/Microsoft/WinGet/Packages/xhcoding.sshpass-win32*/sshpass.exe" | head -n 1 || true)"
  if [[ -n "$MATCHED_SSHPASS" ]]; then
    SSHPASS_BIN="$MATCHED_SSHPASS"
  fi
fi

if [[ -z "$SSHPASS_BIN" ]]; then
  echo "Error: sshpass not found"
  exit 1
fi

if [[ ! -f "$PASSWORD_FILE" ]]; then
  echo "Error: password file not found: $PASSWORD_FILE"
  exit 1
fi

PASSWORD="$(<"$PASSWORD_FILE")"
PASSWORD="${PASSWORD%$'\r'}"
PASSWORD="${PASSWORD%$'\n'}"

if [[ -z "$PASSWORD" ]]; then
  echo "Error: password file is empty"
  exit 1
fi

# Base64 avoids remote shell escaping issues for passwords containing special chars.
PASS_B64="$(printf '%s' "$PASSWORD" | base64 | tr -d '\r\n')"

"$SSHPASS_BIN" -p "$PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$PI_USER@$PI_HOST" "PASS_B64='$PASS_B64' bash -s" <<'REMOTE_EOF'
set -euo pipefail

PASS="$(printf '%s' "$PASS_B64" | base64 -d)"

printf '%s\n' "$PASS" | sudo -S -p '' bash -lc '
set -euo pipefail

# Clean up known bad lines from previous failed attempts.
sed -i '/^rev61272$/d' /etc/fstab || true

mkdir -p /mnt/usbdata /mnt/usbdata/docker /mnt/usbdata/containerd /var/lib/containerd

cat > /etc/docker/daemon.json <<"EOF"
{
  "data-root": "/mnt/usbdata/docker"
}
EOF

# Ensure containerd is bind-mounted to USB.
grep -q "^/mnt/usbdata/containerd /var/lib/containerd none bind 0 0$" /etc/fstab || echo "/mnt/usbdata/containerd /var/lib/containerd none bind 0 0" >> /etc/fstab

mount -a

systemctl stop docker.service docker.socket containerd.service || true
rsync -aHAX --delete /var/lib/containerd/ /mnt/usbdata/containerd/ || true
systemctl daemon-reload
systemctl start containerd.service
systemctl start docker.socket
systemctl start docker.service
'

echo '=== docker root ==='
docker info --format '{{.DockerRootDir}}'

echo '=== mounts ==='
mount | grep -E '/mnt/usbdata|/var/lib/containerd' || true

echo '=== disk ==='
df -h / /mnt/usbdata /var/lib/containerd

cd /home/pi/rpiai
docker compose pull
docker compose up -d
docker compose ps
docker compose logs --tail=80 samatha-ai
REMOTE_EOF
