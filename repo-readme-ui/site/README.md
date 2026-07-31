# rpiai - Repository Overview

This repository builds a Raspberry Pi based AI assistant hub.
It combines local AI inference, voice services, automation integrations, monitoring, and web interfaces.

## What This Repo Contains

* Docker stack for AI assistant services
* Samatha AI based on Open WebUI behind Caddy HTTPS reverse proxy
* Ollama for local model inference
* Automation MCP server for tool integrations
* Wyoming Whisper speech-to-text service
* Wyoming Piper text-to-speech service
* Monitoring and operations containers
* Backup automation
* Optional kiosk and camera related assets

## Access URLs (Use IP Address Or DNS Name)

Replace `<RPi-IP-or-DNS>` with your Raspberry Pi IP address or DNS name.

Example:

```
rpiai.local
```

| Service                           | URL                                                          | Internal Port |
| --------------------------------- | ------------------------------------------------------------ | ------------- |
| Repository README UI via Caddy    | [`https://<RPi-IP>/`](https://192.168.1.1)                   | 80            |
| Repository README UI via Caddy    | [`https://<RPi-DNS>/readme`](https://rpiai.local/readme)     | 80            |
| Samatha AI / Open WebUI via Caddy | [`https://<RPi-DNS>/`](https://rpiai.local/)                 | 8080          |
| RPi Monitor (Glances) via Caddy   | [`https://<RPi-DNS>/monitor/`](https://rpiai.local/monitor/) | 61208         |

## Direct API Endpoints

These endpoints are mainly useful for integrations and diagnostics.

| Service               | Endpoint                         |
| --------------------- | -------------------------------- |
| Ollama API            | `http://rpiai.local:11434`       |
| Automation MCP health | `http://rpiai.local:8080/health` |

## Run Main Stack With Caddy Routing

From the repository root:

```bash
docker compose up -d --build
```

To rebuild only the README UI and Caddy:

```bash
docker compose up -d --build repo-readme-ui caddy
```

## Docker Services

| Container               | Purpose                           |
| ----------------------- | --------------------------------- |
| `ollama`                | Local AI model inference          |
| `samatha-ai`            | Web interface for AI assistant    |
| `automation-mcp-server` | Automation tools and integrations |
| `wyoming-whisper`       | Speech recognition                |
| `wyoming-piper`         | Text-to-speech                    |
| `rpi-monitor`           | Raspberry Pi monitoring           |
| `caddy`                 | HTTPS reverse proxy               |
| `watchtower`            | Automatic container updates       |
| `auto-backup`           | Data backup service               |
| `stack-ops`             | Stack health and operations       |

## Notes

* Caddy provides HTTPS access for all web interfaces.
* If Caddy uses `tls internal`, your browser may show a certificate warning until the local CA is trusted.
* Watchtower only updates containers with the label:

```yaml
com.centurylinklabs.watchtower.enable: "true"
```

* Data is stored in Docker volumes and backed up by the automatic backup service.
* For troubleshooting, check container status:

```bash
docker ps
```

View container logs:

```bash
docker logs <container-name>
```
