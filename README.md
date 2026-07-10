# rpiai

Goal of this repository is to build a Raspberry Pi based AI assistant hub that coordinates remote home automation devices, for example Homey and Home Assistant.

## Setup Guides

- Readme map: [readme/README.md](readme/README.md)
- 2a update/upgrade and Docker install: [readme/2a-update-upgrade-docker.md](readme/2a-update-upgrade-docker.md)
- 4 Docker container with AI Samatha: [readme/4-docker-container-samatha.md](readme/4-docker-container-samatha.md)
- 5 JARVIS kiosk interface with Samantha: [readme/5-jarvis-kiosk-interface.md](readme/5-jarvis-kiosk-interface.md)
- 5b Kiosk autostart and repeatable runbook: [readme/5b-kiosk-autostart-runbook.md](readme/5b-kiosk-autostart-runbook.md)

## Project Goal

- Raspberry Pi host with Docker
- AI assistant container (Samatha)
- Connectivity to Homey and Home Assistant APIs
- Local hardware interface (HDMI touchscreen and camera)

## 1. Create SSD Disk With Raspberry Pi Image

1. Download and open Raspberry Pi Imager on your PC.
2. Insert the SSD (via USB adapter) into your PC.
3. Choose:
	 - Device: your Raspberry Pi model
	 - OS: Raspberry Pi OS (64-bit recommended)
	 - Storage: your SSD
4. Open Advanced options in Imager:
	 - Enable SSH
	 - Set hostname to rpiai
	 - Configure Wi-Fi (SSID, password, country)
	 - Set username and password
5. Write the image and safely eject the SSD.
6. Insert SSD in Raspberry Pi and boot.

Notes:
- Hostname rpiai should typically be reachable as rpiai.local on most home networks.
- If mDNS is not working in your network, find the IP from your router and connect by IP.

## 2. Connect From VS Code To Remote RPI

Install VS Code extensions:
- Remote - SSH

Add SSH host from Windows terminal:

```powershell
ssh-keygen -t ed25519
ssh-copy-id <pi-user>@rpiai.local
```

If ssh-copy-id is not available on Windows, copy your public key manually:

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

Then append that key to the Pi file:

```bash
~/.ssh/authorized_keys
```

In VS Code:
1. Open Command Palette.
2. Select Remote-SSH: Connect to Host.
3. Connect to <pi-user>@rpiai.local.

## 2a. Install Docker On Raspberry Pi

Run on the Raspberry Pi:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
docker run hello-world
```

Optional Docker Compose plugin check:

```bash
docker compose version
```

## 3. Install Hardware

## 3a. Install Logitech C270 (In Transport)

When camera arrives:

1. Plug Logitech C270 into USB port.
2. Verify detection:

```bash
lsusb
v4l2-ctl --list-devices
```

3. Test camera stream:

```bash
sudo apt update
sudo apt install -y fswebcam v4l-utils
fswebcam test.jpg
```

## 4. Docker Container With AI Samatha

Use the repository compose file: [docker-compose.yml](docker-compose.yml)

Start it on the Raspberry Pi from the repository root:

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Check logs:

```bash
docker compose logs --tail=100 samatha-ai
```

Lightweight monitoring (host + containers):

```text
http://rpiai.local:61208
```

Open browser:

```text
http://rpiai.local:3000
```

## 5. JARVIS Kiosk Interface With Samantha

For a complete Chapter 5 setup of a fullscreen JARVIS-style interface on Raspberry Pi,
see: [readme/5-jarvis-kiosk-interface.md](readme/5-jarvis-kiosk-interface.md)

## 5b. Kiosk Autostart And Repeatable Runbook

For repeatable host-based operations and kiosk autostart setup,
see: [readme/5b-kiosk-autostart-runbook.md](readme/5b-kiosk-autostart-runbook.md)

## 6. Use Homey API Endpoint To Open "hek"

The exact endpoint depends on how "hek" is represented in Homey:

- As a device capability
- As a Flow / Advanced Flow action

### 6.1 Get Homey Access Token

Create a long-lived token in Homey developer tools and store it safely.

### 6.2 If "hek" Is A Device Capability

1. Query devices and find the device id and capability id for hek/open action.
2. Trigger capability update.

Example request pattern:

```bash
curl -X PUT "https://<homey-id>.connect.athom.com/api/manager/devices/device/<device-id>/capability/<capability-id>" \
	-H "Authorization: Bearer <homey-token>" \
	-H "Content-Type: application/json" \
	-d '{"value": true}'
```

### 6.3 If "hek" Is A Flow

Create or identify a Flow in Homey that opens hek, then trigger it through Homey Web API/Flow trigger endpoint with bearer token.

## Next Repository Steps

- Add a folder for deployment files:
	- .env.example
	- scripts for Homey and Home Assistant API calls
- Add health checks and auto-restart policy
- Add secure token handling using environment variables

## Action Hub (Persistent Actions)

The repository now includes an Action Hub service that stores action history in SQLite and can execute actions against Home Assistant and Homey.

Files:

- `action-hub/server.py`
- `action-hub/Dockerfile`
- `action-hub/README.md`

Run with Docker Compose:

```bash
cp .env.example .env
# fill in tokens and optional HOMEY_BASE_URL
docker compose up -d --build action-hub jarvis-ui
```

Samatha OpenAI/OpenAPI config:

```bash
# in .env
SAMATHA_OPENAI_API_BASE_URL=https://api.openai.com/v1
SAMATHA_OPENAI_API_KEY=<your_openai_or_openapi_token>

# apply to running container
docker compose up -d samatha-ai
```

Endpoints:

- `GET /health`
- `GET /api/actions?limit=50`
- `POST /api/actions`
- `POST /api/actions/execute`

Monitoring endpoints (Glances API):

- `GET http://<host>:61208/api/4/quicklook`
- `GET http://<host>:61208/api/4/docker`

UI integration:

- `jarvis-ui/app.js` fetches actions from `http://<host>:3002/api/actions`
- falls back to built-in sample data when Action Hub is unavailable

## Full Repeat Flow (Host + Scripts)

Run all operations on the Raspberry Pi host from the repository root.
Containers stay on host (Docker Compose); automation stays in scripts.

Single command from local Git Bash (sync from git + enforce Samatha container-first config + deploy):

```bash
./scripts/rpi-sync-deploy-samatha.sh pi rpiai.local main ~/rpiai 120
```

Useful modes:

```bash
# Check local + RPi git state only (no deploy)
./scripts/rpi-sync-deploy-samatha.sh --status-only

# Force RPi to match git exactly, then deploy
./scripts/rpi-sync-deploy-samatha.sh --force-sync
```

```bash
# 1) OS update + Docker install
./scripts/rpi-2a-update-upgrade-docker.sh pi

# 2) Or deploy/update directly from local Git Bash in one command
./scripts/rpi-sync-deploy-samatha.sh

# 3) Verify container + API
./scripts/rpi-verify-samatha.sh

# 4) Configure kiosk autostart
./scripts/rpi-5b-setup-kiosk.sh http://localhost:3001 pi
```
