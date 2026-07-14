# rpiai - Repository Overview

This repository builds a Raspberry Pi based AI assistant hub.
It combines local AI inference, voice services, automation integrations,
and web interfaces for monitoring and control.

## What This Repo Contains

- Docker stack for AI assistant services
- Open WebUI based interface (`samatha-ai` behind Caddy)
- Ollama for local model inference
- Automation MCP server for tool integrations
- Wyoming Whisper/Piper voice services
- Monitoring and operations containers
- Optional kiosk and camera related assets

## Access URLs (Use IP Address Or DNS Name)

Replace `<RPi-IP-or-DNS>` with your real Raspberry Pi IP or DNS name
(for example `192.168.1.1` or `rpiai.local`).

| Service GUI | URL | Port |
|---|---|---|
| This README UI container | `http://<RPi-IP-or-DNS>:80` | 80 |
| Samatha / Open WebUI (via Caddy HTTPS) | `https://<RPi-IP-or-DNS>:3000` | 3000 |
| RPi Monitor (Glances web UI) | `http://<RPi-IP-or-DNS>:61208` | 61208 |

## API Endpoints (Not GUI, But Useful)

- Ollama: `http://<RPi-IP-or-DNS>:11434`
- Automation MCP health: `http://<RPi-IP-or-DNS>:8080/health`

## Run This README Container

From the repo root:

```bash
docker compose -f docker-compose.readme-ui.yml up -d --build
```

Then open:

- `http://<RPi-IP-or-DNS>:80`

## Notes

- Port 80 may already be used by the existing `caddy` container in the main stack.
- If port 80 is in use, stop Caddy first or run this README UI on another host port.
