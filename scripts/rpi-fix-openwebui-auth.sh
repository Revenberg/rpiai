#!/usr/bin/env bash
set -euo pipefail

cd ~/rpiai

docker compose exec -T samatha-ai python - <<'PY'
import sqlite3

DB = '/app/backend/data/webui.db'
con = sqlite3.connect(DB)
cur = con.cursor()

cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = {r[0] for r in cur.fetchall()}
print('tables:', sorted(tables))

def columns(table):
    cur.execute(f"PRAGMA table_info({table})")
    return [r[1] for r in cur.fetchall()]

updated = 0
for table in ('user', 'users', 'auth'):
    if table not in tables:
        print(f"skip missing table: {table}")
        continue
    cols = columns(table)
    print(f"columns({table}):", cols)
    table_q = f'"{table}"'
    try:
        if 'role' in cols:
            cur.execute(
                f"UPDATE {table_q} SET role='admin' "
                f"WHERE lower(coalesce(role,'')) IN ('pending','user','')"
            )
            print(f"updated {table}.role:", cur.rowcount)
            updated += max(cur.rowcount, 0)
        if 'status' in cols:
            cur.execute(f"UPDATE {table_q} SET status='active' WHERE status IS NULL OR lower(status) != 'active'")
            print(f"updated {table}.status:", cur.rowcount)
            updated += max(cur.rowcount, 0)
        if 'active' in cols:
            cur.execute(f"UPDATE {table_q} SET active=1 WHERE active IS NULL OR active != 1")
            print(f"updated {table}.active:", cur.rowcount)
            updated += max(cur.rowcount, 0)
        if 'disabled' in cols:
            cur.execute(f"UPDATE {table_q} SET disabled=0 WHERE disabled IS NULL OR disabled != 0")
            print(f"updated {table}.disabled:", cur.rowcount)
            updated += max(cur.rowcount, 0)
        if 'verified' in cols:
            cur.execute(f"UPDATE {table_q} SET verified=1 WHERE verified IS NULL OR verified != 1")
            print(f"updated {table}.verified:", cur.rowcount)
            updated += max(cur.rowcount, 0)
    except Exception as exc:
        print(f"update error on {table}: {exc}")

# Try to disable auth-like flags in config table if present.
if 'config' in tables:
    cols = columns('config')
    print('config columns:', cols)
    if 'key' in cols and 'value' in cols:
        cur.execute("UPDATE config SET value='false' WHERE key IN ('WEBUI_AUTH','ENABLE_SIGNUP','auth','webui.auth')")
        print('updated config key/value rows:', cur.rowcount)
        cur.execute("INSERT OR REPLACE INTO config(key, value, updated_at) VALUES('WEBUI_AUTH', 'false', strftime('%s','now'))")
        print('upserted WEBUI_AUTH=false')
    elif 'name' in cols and 'value' in cols:
        cur.execute("UPDATE config SET value='false' WHERE name IN ('WEBUI_AUTH','ENABLE_SIGNUP','auth','webui.auth')")
        print('updated config name/value rows:', cur.rowcount)

con.commit()

for table in ('user', 'users', 'auth'):
    if table in tables:
        cols = columns(table)
        pick = [c for c in ('id','email','role','status','active','disabled','verified') if c in cols]
        if pick:
            cur.execute(f"SELECT {', '.join(pick)} FROM {table} LIMIT 5")
            print(table, cur.fetchall())

con.close()
print('done')
PY

echo '==> Restart samatha-ai'
docker compose up -d --force-recreate samatha-ai
sleep 8
docker compose ps samatha-ai
