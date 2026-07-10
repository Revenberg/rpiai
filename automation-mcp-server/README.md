# automation-mcp-server

Production-ready Automation MCP Server for a local AI assistant (Samantha).

The assistant never talks directly to Homey or Home Assistant. All automation traffic goes through this server.

## Features

- Python 3.12 + FastAPI + MCP Python SDK
- Modular provider pattern: Tools -> Provider -> REST API
- Homey tools and Home Assistant tools (multi-instance)
- YAML configuration
- Optional JWT validation for incoming API requests
- Structured JSON logging via structlog
- Async HTTP via httpx + asyncio
- Unit tests
- Docker + Docker Compose deployment

## Architecture

The project enforces strict separation:

- Tool layer: MCP tool definitions and validation
- Provider layer: all outbound REST communication
- API layer: FastAPI app hosting health/meta and MCP endpoint

Flow:

- Homey Tool -> Homey Provider -> Homey API
- HA Tool -> HA Provider -> Home Assistant API

## Directory structure

```text
automation-mcp-server/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── models.py
│   ├── logging.py
│   ├── providers/
│   │   ├── homey.py
│   │   └── homeassistant.py
│   ├── tools/
│   │   ├── homey_tools.py
│   │   └── ha_tools.py
│   └── utils/
│       ├── instrumentation.py
│       └── responses.py
├── tests/
│   ├── test_config.py
│   └── test_responses.py
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── config.yaml.example
└── README.md
```

## Configuration

Copy and edit config:

```bash
cp config.yaml.example config.yaml
```

Example:

```yaml
homey:
  enabled: true
  base_url: https://xxxxx.connect.athom.com
  bearer_token: YOUR_HOMEY_TOKEN

homeassistant:
  instances:
    home:
      url: http://192.168.1.10:8123
      token: LONG_LIVED_TOKEN
    scouting:
      url: http://192.168.1.20:8123
      token: LONG_LIVED_TOKEN
```

You can add any number of HA instances by adding keys under homeassistant.instances.

## JWT support

Optional JWT auth can be enabled in config.yaml:

```yaml
jwt:
  enabled: true
  secret_key: your_secret
  algorithm: HS256
  audience: your_audience
  issuer: your_issuer
```

When enabled, the REST meta endpoint requires a bearer token. MCP clients should send Authorization headers when needed.

## Homey token creation

1. Open Homey developer tooling / Web API docs.
2. Create a long-lived token.
3. Place token in config.yaml under homey.bearer_token.
4. Keep tokens out of git.

## Home Assistant long-lived token creation

1. Open your HA profile page.
2. Scroll to Long-Lived Access Tokens.
3. Create token.
4. Place token in config.yaml under each instance token.

## Run with Docker Compose

```bash
docker compose up -d --build
```

Container name is fixed to automation-mcp-server and restart policy is unless-stopped.

Health check:

```bash
curl http://localhost:8090/health
```

MCP endpoint is mounted at:

```text
http://localhost:8090/mcp
```

## Local development

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp config.yaml.example config.yaml
uvicorn app.main:create_app --factory --reload --host 0.0.0.0 --port 8080
```

## Tests

```bash
pytest -q
```

## MCP tools exposed

### Homey

- homey.devices()
- homey.device(device_id)
- homey.turn_on(device)
- homey.turn_off(device)
- homey.toggle(device)
- homey.set_dim(device, value)
- homey.set_temperature(device, value)
- homey.set_capability(device, capability, value)
- homey.run_flow(flow_name)
- homey.flow_cards()
- homey.zones()
- homey.energy()
- homey.get_variable(name)
- homey.set_variable(name, value)

### Home Assistant (all require instance)

- ha.entities(instance)
- ha.states(instance)
- ha.turn_on(instance, entity)
- ha.turn_off(instance, entity)
- ha.toggle(instance, entity)
- ha.call_service(instance, domain, service, data)
- ha.scene(instance, scene)
- ha.script(instance, script)
- ha.get_state(instance, entity)
- ha.history(instance, entity)
- ha.areas(instance)
- ha.devices(instance)
- ha.labels(instance)
- ha.services(instance)

### Monitor (Raspberry Pi)

- monitor.host()
- monitor.containers()

## Example MCP tool calls

Example: turn on a light in HA home instance.

```json
{
  "tool": "ha.turn_on",
  "arguments": {
    "instance": "home",
    "entity": "light.woonkamer"
  }
}
```

Example: set Homey dim.

```json
{
  "tool": "homey.set_dim",
  "arguments": {
    "device": "abcd-device-id",
    "value": 0.4
  }
}
```

All errors are normalized for AI-safe consumption:

```json
{
  "success": false,
  "error": "Homey unreachable"
}
```

## Logging

structlog emits structured JSON logs including:

- tool
- parameters
- duration_ms
- result
- error

This enables easy ingestion into Loki/ELK/OpenSearch later.

## Extending with new providers

Add new providers without changing architecture:

1. Create app/providers/new_provider.py
2. Implement async methods with consistent success/error payloads
3. Register tools in app/tools/new_tools.py
4. Wire registration in app/main.py

Potential future providers:

- MQTT
- Frigate
- PostgreSQL
- Docker
- Ollama
- Whisper
- Piper
- Filesystem
- Agenda
- Weer
- Spotify
- E-mail

This keeps one central automation layer for Samantha while preserving safety and modularity.
