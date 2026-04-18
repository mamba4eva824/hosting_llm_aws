# Inference container (FastAPI + Ollama)

Single image: **Ollama** listens on `127.0.0.1:11434` inside the container; **FastAPI** binds `0.0.0.0:5000` and proxies requests to Ollama. Expose **5000** as the API boundary (see Terraform security group).

## Local run

```bash
docker compose up --build
# http://localhost:5000/health
```

## Push to AWS ECR

From the repo root (after `terraform apply` created the repository):

```bash
chmod +x scripts/push-inference-image.sh
./scripts/push-inference-image.sh
```

Then create or replace the EC2 instance so `user_data` pulls the new image, or use `terraform apply -replace='module.compute.aws_instance.ollama'` if the instance booted before the image existed.
