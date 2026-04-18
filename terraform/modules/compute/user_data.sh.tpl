#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/inference-setup.log) 2>&1

echo "=== Inference container bootstrap ==="

REGION="${aws_region}"
IMAGE="${inference_image}"
MODEL="${ollama_model}"

dnf install -y docker awscli
systemctl enable --now docker

if echo "$IMAGE" | grep -q '\.dkr\.ecr\.'; then
  echo "Logging in to ECR..."
  REGISTRY=$(echo "$IMAGE" | cut -d/ -f1)
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
fi

echo "Pulling image: $IMAGE"
docker pull "$IMAGE"

docker rm -f inference 2>/dev/null || true
docker run -d \
  --name inference \
  --restart unless-stopped \
  -p 5000:5000 \
  -e OLLAMA_MODEL="$MODEL" \
  "$IMAGE"

echo "=== Inference container started (FastAPI :5000) ==="
