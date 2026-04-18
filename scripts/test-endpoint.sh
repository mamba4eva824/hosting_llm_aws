#!/usr/bin/env bash
# Hit the FastAPI health endpoint and send a small chat completion via Ollama (proxied).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/terraform"

IP="$(terraform output -raw instance_public_ip)"
BASE="http://${IP}:5000"

echo "GET $BASE/health"
curl -sf "$BASE/health" | jq . 2>/dev/null || curl -sf "$BASE/health"
echo ""

echo "POST $BASE/v1/chat/completions"
curl -sf "$BASE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 80
  }' | jq . 2>/dev/null || curl -sf "$BASE/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Say hello in one short sentence."}],
    "max_tokens": 80
  }'
echo ""
