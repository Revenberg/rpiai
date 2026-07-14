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
| This README UI via Caddy route | `https://<RPi-IP-or-DNS>:3000/readme` | 3000 |
| Samatha / Open WebUI (via Caddy HTTPS) | `https://<RPi-IP-or-DNS>:3000` | 3000 |
| RPi Monitor (Glances web UI) | `http://<RPi-IP-or-DNS>:61208` | 61208 |

## API Endpoints (Not GUI, But Useful)

- Ollama: `http://<RPi-IP-or-DNS>:11434`
- Automation MCP health: `http://<RPi-IP-or-DNS>:8080/health`

## Run With Main Stack And Caddy Routing

From the repo root:

```bash
docker compose up -d --build repo-readme-ui caddy
```

Then open:

- `https://<RPi-IP-or-DNS>:3000/readme`

## Notes

- If Caddy is configured with `tls internal`, your browser may show a certificate warning.
- You can still run the standalone compose file if you specifically want README on host port 80.
