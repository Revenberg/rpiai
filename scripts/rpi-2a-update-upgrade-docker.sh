#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-$USER}}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: This script must run on Linux (Raspberry Pi)."
  exit 1
fi

echo "==> Step 1/7: apt update"
sudo apt-get update

echo "==> Step 2/7: apt full-upgrade"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade

echo "==> Step 3/7: install prerequisites"
sudo apt-get install -y ca-certificates curl gnupg lsb-release

echo "==> Step 4/7: install Docker engine"
curl -fsSL https://get.docker.com | sh

echo "==> Step 5/7: add user '$TARGET_USER' to docker group"
sudo usermod -aG docker "$TARGET_USER"

echo "==> Step 6/7: enable and start docker service"
sudo systemctl enable --now docker

echo "==> Step 7/7: verify Docker"
docker --version || true
sudo docker run --rm hello-world || true
docker compose version || true

echo
echo "Completed. Reconnect your SSH session so docker group changes take effect for user '$TARGET_USER'."
