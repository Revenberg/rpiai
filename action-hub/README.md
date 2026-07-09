# Action Hub

Persistent action storage and execution gateway for Samantha IO.

## Endpoints

- `GET /health`
- `GET /api/actions?limit=50`
- `POST /api/actions`
- `POST /api/actions/rewrite`
- `POST /api/actions/execute`
- `GET /api/presets`
- `POST /api/presets`
- `PUT /api/presets/{id}`
- `DELETE /api/presets/{id}`

Test without persisting:

```json
{
  "source": "action-builder-test",
  "text": "Zet woonkamerlamp op 40%",
  "target": "home_assistant_energy",
  "command": "call_service",
  "payload": {
    "domain": "light",
    "service": "turn_on",
    "data": {
      "entity_id": "light.woonkamer",
      "brightness_pct": 40
    }
  },
  "test_only": true
}
```

## Execute Payload

```json
{
  "source": "samantha",
  "text": "Aanwezigheid opvragen",
  "target": "home_assistant_presence",
  "command": "get_states",
  "payload": {}
}
```

Supported targets:

- `home_assistant_presence` (`HA_PRESENCE_BASE_URL`, `HA_PRESENCE_TOKEN`)
- `home_assistant_energy` (`HA_ENERGY_BASE_URL`, `HA_ENERGY_TOKEN`)
- `homey` (`HOMEY_BASE_URL`, `HOMEY_TOKEN`)

For Home Assistant service calls, use:

```json
{
  "target": "home_assistant_energy",
  "command": "call_service",
  "payload": {
    "domain": "light",
    "service": "turn_on",
    "data": {
      "entity_id": "light.woonkamer",
      "brightness": 180
    }
  }
}
```

For Homey calls, use:

```json
{
  "target": "homey",
  "command": "request",
  "payload": {
    "method": "POST",
    "path": "/api/manager/flow/flow/<flow-id>/trigger",
    "body": {}
  }
}
```
