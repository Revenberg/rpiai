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
print('tables:', sorted(tables)[:40])

def columns(table):
    cur.execute(f"PRAGMA table_info({table})")
    return [r[1] for r in cur.fetchall()]

updated = 0
for table in ('user', 'users'):
    if table not in tables:
        continue
    cols = columns(table)
    sets = []
    if 'status' in cols:
        sets.append("status='active'")
    if 'active' in cols:
        sets.append('active=1')
    if 'disabled' in cols:
        sets.append('disabled=0')
    if 'verified' in cols:
        sets.append('verified=1')
    if sets:
        sql = f"UPDATE {table} SET " + ', '.join(sets)
        cur.execute(sql)
        print(f"updated {table}:", cur.rowcount)
        updated += cur.rowcount

# Try to disable auth-like flags in config table if present.
if 'config' in tables:
    cols = columns('config')
    print('config columns:', cols)
    if 'key' in cols and 'value' in cols:
        cur.execute("UPDATE config SET value='false' WHERE key IN ('WEBUI_AUTH','ENABLE_SIGNUP','auth','webui.auth')")
        print('updated config key/value rows:', cur.rowcount)
    elif 'name' in cols and 'value' in cols:
        cur.execute("UPDATE config SET value='false' WHERE name IN ('WEBUI_AUTH','ENABLE_SIGNUP','auth','webui.auth')")
        print('updated config name/value rows:', cur.rowcount)

con.commit()

for table in ('user', 'users'):
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
