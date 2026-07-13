#!/bin/sh
set -eu

BACKUP_INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-21600}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
BACKUP_DIR="/backup"
STATE_DIR="/state"

mkdir -p "$BACKUP_DIR" "$STATE_DIR"

make_backup() {
  ts="$(date +%Y%m%d-%H%M%S)"
  dest="$BACKUP_DIR/rpiai-backup-$ts.tgz"

  tar -czf "$dest" \
    -C /src samatha ollama mcp

  find "$BACKUP_DIR" -name 'rpiai-backup-*.tgz' -mtime "+$BACKUP_RETENTION_DAYS" -delete
  date -Iseconds >"$STATE_DIR/last_backup"
}

while true; do
  make_backup
  sleep "$BACKUP_INTERVAL_SECONDS"
done
