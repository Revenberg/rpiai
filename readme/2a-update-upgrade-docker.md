# 2a - Update, Upgrade, And Install Docker On Raspberry Pi

This guide continues step 2a and provides a stored script to update and upgrade Raspberry Pi OS and install Docker.

## Files In This Repository

- Script: [../scripts/rpi-2a-update-upgrade-docker.sh](../scripts/rpi-2a-update-upgrade-docker.sh)
- This guide: [2a-update-upgrade-docker.md](2a-update-upgrade-docker.md)

## What The Script Does

1. Verifies it runs on Linux.
2. Runs apt metadata refresh.
3. Runs full upgrade.
4. Installs base packages needed for Docker setup.
5. Installs Docker with the official convenience script.
6. Adds the selected user to the docker group.
7. Enables Docker service.
8. Runs Docker validation commands.

## Run On Raspberry Pi

From the repository root on the Pi:

```bash
chmod +x scripts/rpi-2a-update-upgrade-docker.sh
./scripts/rpi-2a-update-upgrade-docker.sh pi
```

If your user is not pi:

```bash
./scripts/rpi-2a-update-upgrade-docker.sh <your-user>
```

## Verify

```bash
docker --version
docker run --rm hello-world
docker compose version
```

## Notes

- Group changes apply to new sessions. Reconnect SSH after running the script.
- If Docker commands still fail after reconnect, run: `newgrp docker`
