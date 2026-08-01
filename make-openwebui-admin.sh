#!/bin/sh
set -eu

SCRIPT_VERSION="2026-08-01.1"
echo "[openwebui-admin-init] script version: $SCRIPT_VERSION"

DB="/app/backend/data/webui.db"
ENV_FILE="/work/.env"
SAMATHA_API_BASE_URL="${SAMATHA_API_BASE_URL:-http://samatha-ai:8080}"

EMAIL="pi@home.com"
NAME="Pi Admin"
USERNAME="admin"
PASSWORD="admin"

echo "Wachten op database..."

while [ ! -f "$DB" ]
do
    sleep 5
done

echo "Database gevonden"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Fout: python3 niet gevonden in deze container."
    echo "Gebruik een image met python3 (of voer dit script in samatha-ai uit)."
    exit 1
fi

echo "Admin user reset/create via Python sqlite3..."
python3 - <<EOF
import sqlite3
import time
import uuid
import bcrypt
import sys

db = "$DB"
email = "$EMAIL"
name = "$NAME"
username = "$USERNAME"
password = "$PASSWORD"

con = sqlite3.connect(db)
cur = con.cursor()

cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = {r[0] for r in cur.fetchall()}

if "auth" not in tables or "user" not in tables:
    print("Fout: vereiste tabellen auth/user ontbreken in webui.db")
    sys.exit(1)

now = int(time.time())
uid = str(uuid.uuid4())
hash_pw = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

cur.execute("DELETE FROM auth WHERE email=?", (email,))
cur.execute("DELETE FROM user WHERE email=?", (email,))

cur.execute(
    "INSERT INTO auth (id, email, password, active) VALUES (?, ?, ?, 1)",
    (uid, email, hash_pw),
)

cur.execute(
    """
    INSERT INTO user
    (id, name, email, role, profile_image_url, created_at, updated_at, last_active_at, username)
    VALUES (?, ?, ?, 'admin', '/user.png', ?, ?, ?, ?)
    """,
    (uid, name, email, now, now, now, username),
)

con.commit()

cur.execute("SELECT name,email,role FROM user WHERE email=?", (email,))
row = cur.fetchone()
print("Controle:", row if row else "niet gevonden")
con.close()
EOF

echo "API key opvragen via Open WebUI API..."
API_KEY=$(python3 - <<EOF
import json
import urllib.error
import urllib.request

base = "${SAMATHA_API_BASE_URL}".rstrip("/")
email = "${EMAIL}"
password = "${PASSWORD}"

def request_json(url, method="GET", headers=None, body=None):
    req = urllib.request.Request(url, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    try:
        with urllib.request.urlopen(req, data=data, timeout=20) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            payload = json.loads(raw) if raw else {}
        except Exception:
            payload = {"raw": raw}
        return e.code, payload

status, signin = request_json(
    f"{base}/api/v1/auths/signin",
    method="POST",
    headers={"Content-Type": "application/json"},
    body={"email": email, "password": password},
)

token = (
    signin.get("token")
    or signin.get("access_token")
    or (signin.get("data") or {}).get("token")
)

if status != 200 or not token:
    raise SystemExit("SIGNIN_FAILED")

headers = {"Authorization": f"Bearer {token}"}

status_post, key_post = request_json(
    f"{base}/api/v1/auths/api_key",
    method="POST",
    headers=headers,
)

api_key = (
    key_post.get("api_key")
    or key_post.get("key")
    or (key_post.get("data") or {}).get("api_key")
)

if not api_key:
    status_get, key_get = request_json(
        f"{base}/api/v1/auths/api_key",
        method="GET",
        headers=headers,
    )
    api_key = (
        key_get.get("api_key")
        or key_get.get("key")
        or (key_get.get("data") or {}).get("api_key")
    )

if not api_key:
    raise SystemExit("API_KEY_FAILED")

print(api_key)
EOF
)

if [ -z "$API_KEY" ] || [ "$API_KEY" = "SIGNIN_FAILED" ] || [ "$API_KEY" = "API_KEY_FAILED" ]; then
    echo "Fout: kon geen geldige API key ophalen via Open WebUI API."
    exit 1
fi

echo "API key voor $EMAIL:"
echo "$API_KEY"

if [ -f "$ENV_FILE" ]; then
    echo "SAMATHA_API_KEY opslaan in .env voor Caddy/Jarvis..."
    python3 - <<EOF
from pathlib import Path

env_file = Path("$ENV_FILE")
api_key = "$API_KEY"
lines = env_file.read_text(encoding="utf-8").splitlines() if env_file.exists() else []
updated = False
for i, line in enumerate(lines):
    if line.startswith("SAMATHA_API_KEY="):
        lines[i] = f"SAMATHA_API_KEY={api_key}"
        updated = True
        break
if not updated:
    lines.append(f"SAMATHA_API_KEY={api_key}")
env_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
EOF
    echo "SAMATHA_API_KEY bijgewerkt in .env"
else
    echo "Waarschuwing: $ENV_FILE niet gevonden, .env niet bijgewerkt"
fi

echo "Klaar"

