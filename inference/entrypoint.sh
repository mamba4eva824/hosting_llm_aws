#!/bin/bash
set -euo pipefail

echo "Starting Ollama server..."
ollama serve &
export OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0}"

echo "Waiting for Ollama..."
for _ in $(seq 1 120); do
  if curl -sf "http://127.0.0.1:11434/" >/dev/null 2>&1; then
    echo "Ollama is up."
    break
  fi
  sleep 1
done

if ! curl -sf "http://127.0.0.1:11434/" >/dev/null 2>&1; then
  echo "ERROR: Ollama did not become ready in time."
  exit 1
fi

MODEL="${OLLAMA_MODEL:-gemma2:2b}"
echo "Pulling model: ${MODEL}"
ollama pull "${MODEL}"

echo "Starting FastAPI on :5000"
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port 5000
