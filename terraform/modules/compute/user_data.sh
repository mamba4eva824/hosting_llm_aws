#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/ollama-setup.log) 2>&1

echo "=== Ollama Setup Starting ==="

# 1. Install Ollama
echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# 2. Configure Ollama to listen on all interfaces
echo "Configuring Ollama systemd service..."
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
EOF

# 3. Enable and start Ollama service
echo "Starting Ollama service..."
systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama

# 4. Wait for Ollama to be healthy
echo "Waiting for Ollama to be ready..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:11434/ > /dev/null 2>&1; then
    echo "Ollama is ready after ${i} seconds"
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Ollama failed to start within 30 seconds"
    systemctl status ollama
    exit 1
  fi
  sleep 1
done

# 5. Pull the model
echo "Pulling gemma2:2b model (this may take a few minutes)..."
ollama pull gemma2:2b

echo "=== Ollama Setup Complete ==="
echo "Model: gemma2:2b"
echo "API: http://0.0.0.0:11434"
