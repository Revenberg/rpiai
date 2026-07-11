#!/usr/bin/env bash
set -euo pipefail

# Run on Raspberry Pi from repository root.
# Disables persisted function/tool calling flags in Open WebUI SQLite state.

DB_PATH="/app/backend/data/webui.db"

echo "==> Fix Open WebUI persisted tool/function settings"

docker compose exec -T samatha-ai python - <<'PY'
import json
import sqlite3
from typing import Any

DB_PATH = "/app/backend/data/webui.db"

KEYS_DISABLE_BOOL = {
    "tool",
    "tools",
    "tool_calling",
    "function_call",
    "function_calls",
    "function_calling",
    "code_interpreter",
    "code_execution",
    "enable_tools",
    "enable_tool_calling",
    "enable_function_calling",
    "enable_code_interpreter",
    "enable_code_execution",
}

KEYS_SET_MODE_NONE = {
    "function_calling",
    "tool_calling",
}


def normalize_value(key: str, value: Any):
    lk = key.lower()

    if lk in KEYS_SET_MODE_NONE:
        if isinstance(value, str):
            return "none", value.lower() != "none"

    if lk in KEYS_DISABLE_BOOL:
        if isinstance(value, bool):
            return False, value is not False
        if isinstance(value, str):
            lv = value.lower()
            if lv in {"true", "false", "default", "native", "legacy", "auto", "on", "off"}:
                return "false", lv != "false"
        if isinstance(value, list):
            return [], len(value) > 0
        if value is None:
            return value, False

    return value, False


def walk(obj: Any):
    changed = False

    if isinstance(obj, dict):
        for k in list(obj.keys()):
            v = obj[k]
            nv, c1 = normalize_value(k, v)
            if c1:
                obj[k] = nv
                v = nv
                changed = True

            if isinstance(v, (dict, list)):
                if walk(v):
                    changed = True

    elif isinstance(obj, list):
        for item in obj:
            if isinstance(item, (dict, list)) and walk(item):
                changed = True

    return changed


def update_json_column(cur, table: str, pk_col: str, col: str):
    updates = 0
    cur.execute(f'SELECT "{pk_col}", "{col}" FROM "{table}"')
    rows = cur.fetchall()

    for row_id, raw in rows:
        if raw is None or not isinstance(raw, str):
            continue

        text = raw.strip()
        if not text or text[0] not in '{[':
            continue

        try:
            data = json.loads(raw)
        except Exception:
            continue

        changed = walk(data)
        if not changed:
            continue

        new_raw = json.dumps(data, ensure_ascii=False)
        cur.execute(
            f'UPDATE "{table}" SET "{col}" = ? WHERE "{pk_col}" = ?',
            (new_raw, row_id),
        )
        updates += 1

    return updates


conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = {r[0] for r in cur.fetchall()}

# Candidate table/column combinations used by Open WebUI.
candidates = [
    ("user_settings", "id", "settings"),
    ("chat", "id", "chat"),
    ("chats", "id", "chat"),
    ("model", "id", "params"),
    ("models", "id", "params"),
    ("config", "id", "val"),
]

total = 0
for table, pk, col in candidates:
    if table not in tables:
        continue

    cur.execute(f'PRAGMA table_info("{table}")')
    cols = {c[1] for c in cur.fetchall()}
    if pk not in cols or col not in cols:
        continue

    updated = update_json_column(cur, table, pk, col)
    if updated:
        print(f"updated {table}.{col}: {updated}")
        total += updated

conn.commit()
conn.close()
print(f"total updated rows: {total}")
PY

echo "==> Recreate samatha-ai"
docker compose up -d --force-recreate samatha-ai
