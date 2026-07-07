# 5 - JARVIS Kiosk Interface Met Samantha

Dit hoofdstuk beschrijft hoe je een fullscreen JARVIS-achtige webinterface op de Raspberry Pi draait, gekoppeld aan Samantha AI.

## Architectuur

```text
Raspberry Pi 4
├── Chromium (fullscreen kiosk)
├── JARVIS Dashboard (React/Vite)
├── Samantha AI
├── Home Assistant
├── Homey API
└── Gemini
```

Chromium opent automatisch:

```text
http://localhost:3000
```

Daar draait de JARVIS-interface.

## Interface-indeling

### Midden

- Geanimeerd gezicht (Samantha/JARVIS)
- Mond beweegt tijdens spreken
- Ringanimatie tijdens luisteren

### Rechts

Live transcript:

- Jij: "Open het hek."
- Samantha: "Het hek wordt geopend."

### Onder

Actielog, bijvoorbeeld:

- Woonkamerlamp -> 30%
- Hek geopend
- Thermostaat 20C

### Links

- Home Assistant status
- Energie
- Aanwezigheid
- Weer
- Camera's

## Softwarekeuze

- Frontend: React + Vite
- Styling: Tailwind CSS
- Animaties: Framer Motion
- Gezicht: Live2D of HTML/WebGL-animatie
- Communicatie: WebSocket

## Eventstroom Van Samantha Naar Dashboard

Samantha stuurt events naar de webinterface, bijvoorbeeld:

```json
{ "event": "speech", "user": "Doe de lamp aan" }
```

```json
{ "event": "reply", "text": "De lamp is ingeschakeld." }
```

```json
{ "event": "action", "device": "Woonkamerlamp", "status": "Aan" }
```

De interface werkt zichzelf direct bij.

## Automatisch Starten Op De Pi

Na opstarten van de Pi:

1. Docker start.
2. Samantha start.
3. Home Assistant koppelt.
4. Chromium start in kioskmodus.
5. Het dashboard verschijnt direct.

Voorbeeld kiosk-commando:

```bash
chromium \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  http://localhost:3000
```

Voor een volledig herhaalbare setup met scripts, zie:
[5b-kiosk-autostart-runbook.md](5b-kiosk-autostart-runbook.md)

## Aanbevolen Repository-indeling

```text
jarvis-rpi/
├── install.sh
├── docker-compose.yml
├── frontend/          # React dashboard
├── ai-agent/          # Samantha + Gemini
├── websocket/         # realtime updates
├── kiosk/             # Chromium autostart
├── themes/
└── docs/
```

## Is Jarvis Een Vrouw?

Nee. JARVIS is in de films een mannelijke AI-stem (Paul Bettany).
FRIDAY is later een vrouwelijke AI-stem (Kerry Condon).

Voor dit project kun je bewust combineren:

- JARVIS-stijl: interface en uitstraling
- Samantha-stijl: stem en persoonlijkheid

Dat geeft een futuristisch dashboard met warme assistentervaring.

## Losse Container Voor De Interface

Bouw de interface als aparte container naast Samantha. Dat maakt beheer en updates eenvoudiger.

### Voorbeeld architectuur

```text
Gemini
  -> Samantha container
    -> WebSocket/REST
      -> Home Assistant
      -> Homey
      -> JarvisUI container
        -> Chromium kiosk
```

### Voorbeeld projectstructuur

```text
jarvis-ui/
├── docker-compose.yml
├── Dockerfile
├── package.json
├── nginx.conf
├── src/
│   ├── components/
│   ├── pages/
│   └── App.jsx
└── public/
```

### Voorbeeld Dockerfile

```dockerfile
FROM node:22 AS build
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### Voorbeeld docker-compose.yml

```yaml
services:
  jarvis-ui:
    build: .
    container_name: jarvis-ui
    ports:
      - "3000:80"
    restart: unless-stopped
```

### Voorbeeld realtime berichten

```json
{ "type": "speech", "speaker": "user", "text": "Open het hek" }
```

```json
{ "type": "speech", "speaker": "assistant", "text": "Het hek wordt geopend." }
```

```json
{ "type": "action", "icon": "gate", "title": "Hek geopend" }
```

```json
{ "type": "state", "listening": true }
```

## Advies

Zet het modulair op zodat je met een enkele installer de Pi volledig kunt inrichten:

- Docker installeren
- Containers starten (Samantha, JarvisUI, extra services)
- Chromium kioskmodus configureren
- Dashboard automatisch laten verschijnen bij opstarten
