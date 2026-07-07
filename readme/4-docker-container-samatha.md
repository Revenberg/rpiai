# 4 - Docker Container With AI Samatha

This guide runs Samatha in Docker using the repository compose file.

## Files

- Compose file: [../docker-compose.yml](../docker-compose.yml)
- Deploy script: [../scripts/rpi-4-deploy-samatha.sh](../scripts/rpi-4-deploy-samatha.sh)
- Verify script: [../scripts/rpi-verify-samatha.sh](../scripts/rpi-verify-samatha.sh)
- This guide: [4-docker-container-samatha.md](4-docker-container-samatha.md)

## Run On Raspberry Pi

From the repository root:

```bash
chmod +x scripts/rpi-4-deploy-samatha.sh scripts/rpi-verify-samatha.sh
./scripts/rpi-4-deploy-samatha.sh
```

## Verify

```bash
./scripts/rpi-verify-samatha.sh
docker compose logs --tail=100 samatha-ai
```

Open in browser:

```text
http://rpiai.local:3000
```

## Stop And Start

```bash
docker compose stop
docker compose start
```

## Repeatable Host Actions

All container actions run on the Raspberry Pi host from this repository:

```bash
# Deploy/update container
./scripts/rpi-4-deploy-samatha.sh

# Quick health check
./scripts/rpi-verify-samatha.sh

# Restart service only
docker compose restart samatha-ai
```
