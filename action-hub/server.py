import json
import os
import re
import sqlite3
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib import error, parse, request

DB_PATH = os.environ.get("ACTION_DB_PATH", "/data/actions.db")
HOST = os.environ.get("ACTION_HUB_HOST", "0.0.0.0")
PORT = int(os.environ.get("ACTION_HUB_PORT", "3002"))

HA_PRESENCE_BASE = os.environ.get("HA_PRESENCE_BASE_URL", "http://192.168.1.80:8123")
HA_ENERGY_BASE = os.environ.get("HA_ENERGY_BASE_URL", "http://192.168.1.123:8123")
HOMEY_BASE = os.environ.get("HOMEY_BASE_URL", "")
SAMATHA_BASE = os.environ.get("SAMATHA_BASE_URL", "http://samatha-ai:8080")

HA_PRESENCE_TOKEN = os.environ.get("HA_PRESENCE_TOKEN", "")
HA_ENERGY_TOKEN = os.environ.get("HA_ENERGY_TOKEN", "")
HOMEY_TOKEN = os.environ.get("HOMEY_TOKEN", "")
SAMATHA_API_KEY = os.environ.get("SAMATHA_API_KEY", "")


def utc_now_iso():
    return datetime.now(timezone.utc).isoformat()


def db_connect():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with db_connect() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS action_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                source TEXT NOT NULL,
                text TEXT NOT NULL,
                status TEXT NOT NULL,
                target TEXT,
                command TEXT,
                payload_json TEXT,
                result_json TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS action_preset (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                name TEXT NOT NULL UNIQUE,
                text TEXT NOT NULL,
                target TEXT NOT NULL,
                command TEXT NOT NULL,
                payload_json TEXT NOT NULL
            )
            """
        )
        conn.commit()

    seed_default_presets()


def insert_action(source, text, status="queued", target=None, command=None, payload=None, result=None):
    payload_json = json.dumps(payload or {}, ensure_ascii=True)
    result_json = json.dumps(result or {}, ensure_ascii=True)
    with db_connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO action_log
            (created_at, source, text, status, target, command, payload_json, result_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (utc_now_iso(), source, text, status, target, command, payload_json, result_json),
        )
        conn.commit()
        return cur.lastrowid


def list_actions(limit=50):
    limit = max(1, min(limit, 500))
    with db_connect() as conn:
        rows = conn.execute(
            """
            SELECT id, created_at, source, text, status, target, command, payload_json, result_json
            FROM action_log
            ORDER BY id DESC
            LIMIT ?
            """,
            (limit,),
        ).fetchall()

    data = []
    for row in rows:
        data.append(
            {
                "id": row["id"],
                "created_at": row["created_at"],
                "source": row["source"],
                "text": row["text"],
                "status": row["status"],
                "target": row["target"],
                "command": row["command"],
                "payload": json.loads(row["payload_json"] or "{}"),
                "result": json.loads(row["result_json"] or "{}"),
            }
        )
    return data


def seed_default_presets():
    with db_connect() as conn:
        row = conn.execute("SELECT COUNT(*) AS n FROM action_preset").fetchone()
        count = int(row["n"] if row else 0)
        if count > 0:
            return

        now = utc_now_iso()
        presets = [
            (
                now,
                now,
                "Aanwezigheid status",
                "Controleer aanwezigheid status",
                "home_assistant_presence",
                "get_states",
                json.dumps({}, ensure_ascii=True),
            ),
            (
                now,
                now,
                "Woonkamer licht 40%",
                "Zet woonkamerlicht op 40%",
                "home_assistant_energy",
                "call_service",
                json.dumps(
                    {
                        "domain": "light",
                        "service": "turn_on",
                        "data": {
                            "entity_id": "light.woonkamer",
                            "brightness_pct": 40,
                        },
                    },
                    ensure_ascii=True,
                ),
            ),
            (
                now,
                now,
                "Open hek (Homey)",
                "Open het hek via Homey flow",
                "homey",
                "request",
                json.dumps(
                    {
                        "method": "POST",
                        "path": "/api/manager/flow/flow/<flow-id>/trigger",
                        "body": {},
                    },
                    ensure_ascii=True,
                ),
            ),
        ]

        conn.executemany(
            """
            INSERT INTO action_preset
            (created_at, updated_at, name, text, target, command, payload_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            presets,
        )
        conn.commit()


def list_presets():
    with db_connect() as conn:
        rows = conn.execute(
            """
            SELECT id, created_at, updated_at, name, text, target, command, payload_json
            FROM action_preset
            ORDER BY name COLLATE NOCASE ASC
            """
        ).fetchall()

    data = []
    for row in rows:
        data.append(
            {
                "id": row["id"],
                "created_at": row["created_at"],
                "updated_at": row["updated_at"],
                "name": row["name"],
                "text": row["text"],
                "target": row["target"],
                "command": row["command"],
                "payload": json.loads(row["payload_json"] or "{}"),
            }
        )
    return data


def insert_preset(name, text, target, command, payload):
    now = utc_now_iso()
    payload_json = json.dumps(payload or {}, ensure_ascii=True)
    with db_connect() as conn:
        cur = conn.execute(
            """
            INSERT INTO action_preset
            (created_at, updated_at, name, text, target, command, payload_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (now, now, name, text, target, command, payload_json),
        )
        conn.commit()
        return cur.lastrowid


def update_preset(preset_id, name, text, target, command, payload):
    now = utc_now_iso()
    payload_json = json.dumps(payload or {}, ensure_ascii=True)
    with db_connect() as conn:
        cur = conn.execute(
            """
            UPDATE action_preset
            SET updated_at = ?, name = ?, text = ?, target = ?, command = ?, payload_json = ?
            WHERE id = ?
            """,
            (now, name, text, target, command, payload_json, preset_id),
        )
        conn.commit()
        return cur.rowcount > 0


def delete_preset(preset_id):
    with db_connect() as conn:
        cur = conn.execute("DELETE FROM action_preset WHERE id = ?", (preset_id,))
        conn.commit()
        return cur.rowcount > 0


def parse_preset_id(path):
    m = re.fullmatch(r"/api/presets/(\d+)", path)
    if not m:
        return None
    return int(m.group(1))


def perform_http_call(base_url, token, method, path, body):
    full_url = base_url.rstrip("/") + "/" + path.lstrip("/")
    data = None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    if body is not None:
        data = json.dumps(body, ensure_ascii=True).encode("utf-8")

    req = request.Request(full_url, data=data, method=method.upper(), headers=headers)
    try:
        with request.urlopen(req, timeout=12) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            try:
                parsed = json.loads(raw) if raw else {}
            except json.JSONDecodeError:
                parsed = {"raw": raw}
            return {"ok": True, "status": resp.status, "data": parsed}
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        return {"ok": False, "status": exc.code, "error": raw}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "status": 0, "error": str(exc)}


def execute_action(payload):
    target = payload.get("target", "")
    command = payload.get("command", "")
    body = payload.get("payload", {})

    if target == "home_assistant_presence":
        if command == "get_states":
            return perform_http_call(HA_PRESENCE_BASE, HA_PRESENCE_TOKEN, "GET", "/api/states", None)
        if command == "call_service":
            domain = body.get("domain", "")
            service = body.get("service", "")
            service_data = body.get("data", {})
            path = f"/api/services/{domain}/{service}"
            return perform_http_call(HA_PRESENCE_BASE, HA_PRESENCE_TOKEN, "POST", path, service_data)

    if target == "home_assistant_energy":
        if command == "get_states":
            return perform_http_call(HA_ENERGY_BASE, HA_ENERGY_TOKEN, "GET", "/api/states", None)
        if command == "call_service":
            domain = body.get("domain", "")
            service = body.get("service", "")
            service_data = body.get("data", {})
            path = f"/api/services/{domain}/{service}"
            return perform_http_call(HA_ENERGY_BASE, HA_ENERGY_TOKEN, "POST", path, service_data)

    if target == "homey":
        method = body.get("method", "POST")
        path = body.get("path", "")
        req_body = body.get("body", {})
        if not HOMEY_BASE:
            return {"ok": False, "status": 0, "error": "HOMEY_BASE_URL is not configured"}
        return perform_http_call(HOMEY_BASE, HOMEY_TOKEN, method, path, req_body)

    return {"ok": False, "status": 0, "error": "Unknown target/command"}


def _extract_model_id(models_payload):
    data = models_payload.get("data")
    if isinstance(data, list) and data:
        model_id = data[0].get("id")
        if isinstance(model_id, str) and model_id:
            return model_id
    return None


def _resolve_samatha_model():
    result = perform_http_call(SAMATHA_BASE, SAMATHA_API_KEY, "GET", "/api/models", None)
    if not result.get("ok"):
        return None
    return _extract_model_id(result.get("data", {}))


def rewrite_text_with_samatha(text, target, command, payload):
    model_id = _resolve_samatha_model()

    if not model_id:
        cleaned = text.strip().capitalize()
        return {
            "ok": True,
            "suggested_text": cleaned,
            "provider": "fallback",
            "note": "No Samatha model detected; fallback normalization used",
        }

    system_prompt = (
        "Je bent Samantha, een home automation assistent. "
        "Herschrijf de actieomschrijving kort, duidelijk en in correct Nederlands. "
        "Gebruik 1 zin, zonder extra uitleg."
    )
    user_prompt = (
        f"Origineel: {text}\n"
        f"Target: {target}\n"
        f"Command: {command}\n"
        f"Payload: {json.dumps(payload or {}, ensure_ascii=True)}"
    )

    body = {
        "model": model_id,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    }
    result = perform_http_call(SAMATHA_BASE, SAMATHA_API_KEY, "POST", "/api/chat/completions", body)
    if not result.get("ok"):
        cleaned = text.strip().capitalize()
        return {
            "ok": True,
            "suggested_text": cleaned,
            "provider": "fallback",
            "note": f"Samatha request failed: {result.get('error', 'unknown error')}",
        }

    data = result.get("data", {})
    choices = data.get("choices", [])
    if not choices:
        cleaned = text.strip().capitalize()
        return {
            "ok": True,
            "suggested_text": cleaned,
            "provider": "fallback",
            "note": "Samatha returned no choices",
        }

    content = choices[0].get("message", {}).get("content", "")
    improved = str(content).strip() or text.strip().capitalize()
    return {
        "ok": True,
        "suggested_text": improved,
        "provider": "samatha-ai",
        "model": model_id,
    }


def _as_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "y", "on"}
    if isinstance(value, (int, float)):
        return value != 0
    return False


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length > 0 else b"{}"
        return json.loads(raw.decode("utf-8"))

    def do_OPTIONS(self):
        self._send_json(200, {"ok": True})

    def do_GET(self):
        parsed = parse.urlparse(self.path)

        if parsed.path == "/health":
            self._send_json(200, {"ok": True, "service": "action-hub"})
            return

        if parsed.path == "/api/actions":
            query = parse.parse_qs(parsed.query)
            limit = int(query.get("limit", ["50"])[0])
            self._send_json(200, {"ok": True, "actions": list_actions(limit)})
            return

        if parsed.path == "/api/presets":
            self._send_json(200, {"ok": True, "presets": list_presets()})
            return

        self._send_json(404, {"ok": False, "error": "Not found"})

    def do_POST(self):
        parsed = parse.urlparse(self.path)

        if parsed.path == "/api/actions":
            try:
                payload = self._read_json()
            except Exception:  # noqa: BLE001
                self._send_json(400, {"ok": False, "error": "Invalid JSON"})
                return

            text = str(payload.get("text", "")).strip()
            source = str(payload.get("source", "manual")).strip() or "manual"
            status = str(payload.get("status", "queued")).strip() or "queued"
            target = str(payload.get("target", "")).strip() or None
            command = str(payload.get("command", "")).strip() or None

            if not text:
                self._send_json(400, {"ok": False, "error": "text is required"})
                return

            new_id = insert_action(
                source=source,
                text=text,
                status=status,
                target=target,
                command=command,
                payload=payload.get("payload"),
                result=payload.get("result"),
            )
            self._send_json(201, {"ok": True, "id": new_id})
            return

        if parsed.path == "/api/actions/rewrite":
            try:
                payload = self._read_json()
            except Exception:  # noqa: BLE001
                self._send_json(400, {"ok": False, "error": "Invalid JSON"})
                return

            text = str(payload.get("text", "")).strip()
            target = str(payload.get("target", "")).strip()
            command = str(payload.get("command", "")).strip()
            body = payload.get("payload", {})

            if not text:
                self._send_json(400, {"ok": False, "error": "text is required"})
                return

            result = rewrite_text_with_samatha(text, target, command, body)
            self._send_json(200, result)
            return

        if parsed.path == "/api/actions/execute":
            try:
                payload = self._read_json()
            except Exception:  # noqa: BLE001
                self._send_json(400, {"ok": False, "error": "Invalid JSON"})
                return

            target = str(payload.get("target", "")).strip()
            command = str(payload.get("command", "")).strip()
            source = str(payload.get("source", "samantha")).strip() or "samantha"
            text = str(payload.get("text", f"execute {target}:{command}")).strip()
            test_only = _as_bool(payload.get("test_only", False))

            if not target or not command:
                self._send_json(400, {"ok": False, "error": "target and command are required"})
                return

            result = execute_action(payload)

            if test_only:
                self._send_json(200, {"ok": result.get("ok", False), "test_only": True, "result": result})
                return

            status = "done" if result.get("ok") else "failed"
            new_id = insert_action(
                source=source,
                text=text,
                status=status,
                target=target,
                command=command,
                payload=payload.get("payload", {}),
                result=result,
            )
            self._send_json(200, {"ok": result.get("ok", False), "id": new_id, "result": result})
            return

        if parsed.path == "/api/presets":
            try:
                payload = self._read_json()
            except Exception:  # noqa: BLE001
                self._send_json(400, {"ok": False, "error": "Invalid JSON"})
                return

            name = str(payload.get("name", "")).strip()
            text = str(payload.get("text", "")).strip()
            target = str(payload.get("target", "")).strip()
            command = str(payload.get("command", "")).strip()
            body = payload.get("payload", {})

            if not name or not text or not target or not command:
                self._send_json(400, {"ok": False, "error": "name, text, target and command are required"})
                return

            try:
                new_id = insert_preset(name, text, target, command, body)
            except sqlite3.IntegrityError:
                self._send_json(409, {"ok": False, "error": "Preset name already exists"})
                return

            self._send_json(201, {"ok": True, "id": new_id})
            return

        self._send_json(404, {"ok": False, "error": "Not found"})

    def do_PUT(self):
        parsed = parse.urlparse(self.path)
        preset_id = parse_preset_id(parsed.path)
        if preset_id is None:
            self._send_json(404, {"ok": False, "error": "Not found"})
            return

        try:
            payload = self._read_json()
        except Exception:  # noqa: BLE001
            self._send_json(400, {"ok": False, "error": "Invalid JSON"})
            return

        name = str(payload.get("name", "")).strip()
        text = str(payload.get("text", "")).strip()
        target = str(payload.get("target", "")).strip()
        command = str(payload.get("command", "")).strip()
        body = payload.get("payload", {})

        if not name or not text or not target or not command:
            self._send_json(400, {"ok": False, "error": "name, text, target and command are required"})
            return

        try:
            updated = update_preset(preset_id, name, text, target, command, body)
        except sqlite3.IntegrityError:
            self._send_json(409, {"ok": False, "error": "Preset name already exists"})
            return

        if not updated:
            self._send_json(404, {"ok": False, "error": "Preset not found"})
            return

        self._send_json(200, {"ok": True, "id": preset_id})

    def do_DELETE(self):
        parsed = parse.urlparse(self.path)
        preset_id = parse_preset_id(parsed.path)
        if preset_id is None:
            self._send_json(404, {"ok": False, "error": "Not found"})
            return

        deleted = delete_preset(preset_id)
        if not deleted:
            self._send_json(404, {"ok": False, "error": "Preset not found"})
            return

        self._send_json(200, {"ok": True, "id": preset_id})


if __name__ == "__main__":
    init_db()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"action-hub running on {HOST}:{PORT}")
    server.serve_forever()
