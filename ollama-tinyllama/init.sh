#!/usr/bin/env bash
set -euo pipefail

MODEL="${OLLAMA_MODEL:-tinyllama}"

log() {
  printf '[init] %s\n' "$*"
}

log "Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

shutdown() {
  log "Stopping Ollama server..."
  kill "$OLLAMA_PID" 2>/dev/null || true
}
trap shutdown INT TERM

log "Waiting for Ollama API on http://127.0.0.1:11434 ..."
until curl -fsS "http://127.0.0.1:11434/api/tags" > /dev/null; do
  sleep 1
done

if curl -fsS "http://127.0.0.1:11434/api/tags" | grep -q "\"name\":\"${MODEL}\""; then
  log "Model '${MODEL}' already present. Skipping download."
else
  log "Model '${MODEL}' not found. Downloading now (first start can take a while)..."
  ollama pull "${MODEL}"
  log "Model '${MODEL}' download completed."
fi

log "Ollama is ready. Streaming logs in foreground."
wait "$OLLAMA_PID"
