#!/usr/bin/env bash
# Build the inference image and push it to the ECR repo created by Terraform.
# Prerequisite: terraform apply (so the repository exists and outputs are available).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${AWS_REGION:-us-west-1}"
TAG="${1:-latest}"

cd "$ROOT/terraform"
REPO_URL="$(terraform output -raw ecr_repository_url)"
IMAGE="$REPO_URL:$TAG"

echo "Building $IMAGE (linux/amd64 for EC2 x86_64) ..."
docker build --platform linux/amd64 -t "$IMAGE" "$ROOT/inference"

echo "Logging in to ECR ($REGION) ..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$(echo "$REPO_URL" | cut -d/ -f1)"

echo "Pushing $IMAGE ..."
docker push "$IMAGE"

echo "Done. If the instance already ran user_data before the image existed, recycle the instance:"
echo "  cd terraform && terraform apply -replace='module.compute.aws_instance.ollama' -var-file=terraform.tfvars"
