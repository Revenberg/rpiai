# Ollama TinyLlama (Raspberry Pi 4 ARM64)

Deze setup draait Ollama met het TinyLlama-model in een ARM64-container, met persistent modelopslag en automatische eerste download.

## Inhoud

- `Dockerfile`
- `docker-compose.yml`
- `.env`
- `init.sh`

## Installatie

1. Ga naar de map:

```bash
cd ollama-tinyllama
```

2. Controleer de configuratie in `.env`:

```bash
cat .env
```

3. Build en start:

```bash
docker compose up -d --build
```

## Starten en stoppen

Starten:

```bash
docker compose up -d
```

Stoppen:

```bash
docker compose down
```

## Updaten

1. Trek de laatste base updates op en rebuild:

```bash
docker compose build --pull --no-cache
docker compose up -d
```

2. Controleer status:

```bash
docker compose ps
```

## Logs bekijken

Container logs:

```bash
docker compose logs -f ollama
```

Tijdens eerste start zie je duidelijke meldingen van `init.sh` over modeldetectie en download.

## Veelvoorkomende problemen

1. Poort 11434 is al in gebruik
- Pas `OLLAMA_PORT` in `.env` aan, bijvoorbeeld `OLLAMA_PORT=21434`.

2. Eerste modeldownload duurt lang
- Normaal op Raspberry Pi. Check met `docker compose logs -f ollama`.

3. Te hoog geheugengebruik
- Gebruik alleen `tinyllama` als model.
- Sluit andere zware containers tijdens inferentie.
- Houd swap actief op de host voor extra stabiliteit.

4. API niet bereikbaar
- Check health en status:

```bash
docker compose ps
curl http://localhost:11434/api/tags
```

## Test na starten

Na succesvolle start werkt:

```bash
curl http://localhost:11434/api/generate \
-d '{
  "model":"tinyllama",
  "prompt":"Hallo Samantha!"
}'
```

## Raspberry Pi 4 optimalisatie

- ARM64 base image (`arm64v8/debian:bookworm-slim`)
- Zo min mogelijk packages (`ca-certificates`, `curl`, `tini`)
- Persistent volume zodat model niet opnieuw hoeft te downloaden
- Healthcheck op de lokale API
- `restart: unless-stopped` voor automatisch herstel
