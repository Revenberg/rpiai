# 5b - Kiosk Autostart En Herhaalbare Runbook

Dit hoofdstuk maakt de kiosk-setup herhaalbaar met scripts in deze repository.
Containers draaien op de Raspberry Pi host via Docker Compose; overige functies draaien via scripts.

## Files In Deze Repository

- Kiosk setup script: [../scripts/rpi-5b-setup-kiosk.sh](../scripts/rpi-5b-setup-kiosk.sh)
- Kiosk launch script: [../scripts/rpi-5b-kiosk-launch.sh](../scripts/rpi-5b-kiosk-launch.sh)
- Samatha deploy script: [../scripts/rpi-4-deploy-samatha.sh](../scripts/rpi-4-deploy-samatha.sh)
- Samatha verify script: [../scripts/rpi-verify-samatha.sh](../scripts/rpi-verify-samatha.sh)
- This guide: [5b-kiosk-autostart-runbook.md](5b-kiosk-autostart-runbook.md)

## Doel

Na boot van de Raspberry Pi:

1. Docker start op de host.
2. Samatha container draait.
3. Chromium start automatisch in kioskmodus.
4. Dashboard opent op http://localhost:3000.

## Eenmalige Setup Op Raspberry Pi

Voer uit op de Pi in de repository root:

```bash
chmod +x scripts/rpi-4-deploy-samatha.sh \
         scripts/rpi-verify-samatha.sh \
         scripts/rpi-5b-setup-kiosk.sh \
         scripts/rpi-5b-kiosk-launch.sh

./scripts/rpi-4-deploy-samatha.sh
./scripts/rpi-verify-samatha.sh
./scripts/rpi-5b-setup-kiosk.sh http://localhost:3000 pi
```

Als je username niet pi is:

```bash
./scripts/rpi-5b-setup-kiosk.sh http://localhost:3000 <your-user>
```

## Wat Het Kiosk Setup Script Doet

- Installeert kiosk dependencies (unclutter en chromium indien nodig).
- Schrijft LXDE autostart instellingen:
- scherm niet dimmen
- cursor verbergen
- kiosk launcher starten
- Verwijst naar repository-script [../scripts/rpi-5b-kiosk-launch.sh](../scripts/rpi-5b-kiosk-launch.sh) met URL parameter.

## Reboot Test

```bash
sudo reboot
```

Na reboot:

- Desktop login opent Chromium in fullscreen op http://localhost:3000.
- Samatha blijft beschikbaar op poort 3000.

## Dagelijkse Bedienacties

Voer uit op de Pi in de repository root:

```bash
# Update/redeploy Samatha container
./scripts/rpi-4-deploy-samatha.sh

# Controleer health en API
./scripts/rpi-verify-samatha.sh

# Bekijk logs
docker compose logs --tail=120 samatha-ai

# Herstart container
docker compose restart samatha-ai
```

## Remote Bediening Vanuit Je PC

Via Git Bash en je connect script:

```bash
./connect-rpiai.sh pi rpiai.local "cd ~/rpiai && ./scripts/rpi-verify-samatha.sh"
./connect-rpiai.sh pi rpiai.local "cd ~/rpiai && docker compose logs --tail=120 samatha-ai"
```

## Browser Toegang

- Lokaal op Pi scherm (kiosk): http://localhost:3000
- Vanaf laptop/desktop in hetzelfde netwerk: http://rpiai.local:3000

Als mDNS niet werkt, gebruik het Pi IP-adres:

```text
http://<pi-ip>:3000
```

## Troubleshooting

1. Zwart scherm of geen kiosk:
- Controleer autostart file: ~/.config/lxsession/LXDE-pi/autostart
- Controleer launch script pad in autostart

2. Container draait niet:
- Run: ./scripts/rpi-4-deploy-samatha.sh
- Controleer logs: docker compose logs --tail=200 samatha-ai

3. Browser vanaf netwerk werkt niet:
- Test poort vanaf Windows:
- Test-NetConnection rpiai.local -Port 3000
- Controleer firewall/router instellingen
