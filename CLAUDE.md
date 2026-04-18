# Ollama on EC2 — Self-Hosted LLM Inference

## Project Overview

Deploy a Docker image on EC2: FastAPI on port **5000** proxies to Ollama (Gemma 2B) inside the container, fully managed with Terraform and automated via GitHub Actions CI/CD.

This is a learning project. Prioritize clarity, cost-safety, and clean infrastructure patterns over production hardening.

## Architecture

```
GitHub Actions (CI/CD)
    │
    ▼
Terraform Cloud / S3 Backend
    │
    ▼
┌──────────────── AWS VPC ────────────────┐
│                                         │
│   Public Subnet (single AZ)             │
│   ┌───────────────────────────────┐     │
│   │  EC2 t3.xlarge · Docker     │     │
│   │  ┌─────────────────────────┐  │     │
│   │  │  FastAPI :5000          │  │     │
│   │  │  → Ollama :11434        │  │     │
│   │  │  (gemma2:2b)            │  │     │
│   │  └─────────────────────────┘  │     │
│   └───────────────────────────────┘     │
│                                         │
│   Security Group: 22 (SSH), 5000 (API)  │
└─────────────────────────────────────────┘
```

## Tech Stack

- **IaC**: Terraform (~> 1.5) with AWS provider
- **Compute**: EC2 t3.xlarge (4 vCPU, 16GB RAM) — CPU inference
- **Runtime**: Docker on EC2 — Ollama + FastAPI in one image (ECR)
- **CI/CD**: GitHub Actions
- **Language**: HCL (Terraform), Bash (scripts)
- **Model**: gemma2:2b (~5-10 tokens/sec on CPU)

## Directory Structure

```
model_hosting_aws/
├── CLAUDE.md                      # This file
├── README.md                      # User-facing setup and usage docs
├── terraform/
│   ├── main.tf                    # Root module, provider config
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Instance IP, API endpoint URL
│   ├── terraform.tfvars.example   # Example variable values (never commit real tfvars)
│   ├── backend.tf                 # S3 remote state config
│   ├── ecr.tf                     # ECR repository for the inference image
│   ├── data.tf                    # AMI lookups (Amazon Linux 2023)
│   ├── modules/
│   │   ├── networking/
│   │   │   ├── main.tf            # VPC, subnet, IGW, route table, security group
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── compute/
│   │       ├── main.tf            # EC2 instance, IAM role, user data
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── user_data.sh.tpl   # Bootstrap: Docker pull + run inference container
├── inference/                     # Dockerfile, FastAPI app, docker-compose
├── scripts/
│   ├── shutdown.sh                # Stop instance to save cost
│   ├── startup.sh                 # Start instance and verify Ollama health
│   └── test-endpoint.sh           # Curl the Ollama API to verify it responds
├── .github/
│   └── workflows/
│       ├── plan.yml               # On PR: fmt, validate, plan
│       ├── apply.yml              # On merge to main: apply
│       └── nightly-shutdown.yml   # Cron: stop instance at midnight
└── dev/
    └── active/                    # Session context files for Claude Code
```

## Conventions and Rules

### Terraform
- Run `terraform fmt` and `terraform validate` before every commit
- Use modules for logical separation (networking, compute)
- Tag ALL resources: `Project = "ollama-learning"`, `ManagedBy = "terraform"`, `Environment = "dev"`
- Use `terraform plan` output in PR comments via GitHub Actions
- Store state remotely in S3 with DynamoDB locking (or use Terraform Cloud free tier)
- Pin provider versions in `versions.tf`

### Secrets Management
- AWS credentials → GitHub Actions OIDC with IAM role (preferred) or access key secrets
- SSH key → GitHub Actions secret or AWS SSM (no hardcoded keys)
- Never commit `.tfvars` files with real values — only `.tfvars.example`

### Cost Protection (CRITICAL)
- Default instance state should be STOPPED — start only when needed
- GitHub Actions nightly cron job stops the instance at midnight UTC
- CloudWatch billing alarm at $50/month threshold
- CloudWatch alarm if instance runs continuously for >8 hours
- Add `prevent_destroy` lifecycle on the instance for safety
- Use spot instances where possible (add a variable to toggle on-demand vs spot)

### Ollama Configuration
- Install via: `curl -fsSL https://ollama.com/install.sh | sh`
- Default port: 11434
- Health check endpoint: `GET /` (returns "Ollama is running")
- API: OpenAI-compatible at `POST /v1/chat/completions`
- Native Ollama API: `POST /api/generate`, `POST /api/chat`
- Model pull: `ollama pull gemma2:2b`
- Inside the container, Ollama listens on 11434; FastAPI listens on **5000** (only 5000 is exposed on the host SG)
- Model weights stored in container volume path `~/.ollama/models` — persist on EBS to avoid re-downloading on restart

### User Data Bootstrap Order
1. Install Docker (and AWS CLI for ECR login)
2. Pull inference image from ECR (or configured registry)
3. Run container publishing port **5000**

## Key Commands

```bash
# Initialize terraform
cd terraform && terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars

# Apply infrastructure
terraform apply -var-file=terraform.tfvars

# Test via FastAPI proxy (OpenAI-compatible)
curl http://$(terraform output -raw instance_public_ip):5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Hello, who are you?"}],
    "max_tokens": 100
  }'

# Test the native Ollama API (proxied under /api)
curl http://$(terraform output -raw instance_public_ip):5000/api/chat \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Hello, who are you?"}]
  }'

# Stop instance to save money
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Destroy everything when done
terraform destroy -var-file=terraform.tfvars
```

## Claude Code Workflow

### Starting a session
```bash
cd model_hosting_aws
claude
```

### Suggested prompt sequence for building this project

**Phase 1 — Scaffold**
1. "Create the directory structure from CLAUDE.md"
2. "Create the networking module: VPC, public subnet, internet gateway, route table, and security group allowing SSH (22) and FastAPI (5000)"
3. "Create the compute module: t3.xlarge EC2 instance using Amazon Linux 2023 AMI, with an IAM instance profile, and user_data that runs the Docker inference image"
4. "Create the root main.tf that wires networking and compute modules together, plus variables.tf, outputs.tf, and terraform.tfvars.example"

**Phase 2 — CI/CD**
5. "Create a GitHub Actions workflow for PRs that runs terraform fmt -check, validate, and plan, then posts the plan as a PR comment"
6. "Create a GitHub Actions workflow for merges to main that runs terraform apply with auto-approve"
7. "Create a nightly shutdown workflow on a cron schedule that stops the EC2 instance"

**Phase 3 — Safety and polish**
8. "Add a CloudWatch billing alarm at $50 and a CloudWatch alarm for instance uptime exceeding 8 hours"
9. "Add scripts/test-endpoint.sh that polls the Ollama health endpoint and then sends a test chat completion"
10. "Run terraform validate and fix any issues"
11. "Write a README with prerequisites, setup instructions, usage examples, cost estimates, and teardown instructions"

### Resuming work across sessions
Keep context in `dev/active/`:
```bash
> "Update dev/active/context.md with what we accomplished and what's next"
```

### Debugging
```bash
# If Ollama won't start, pull the cloud-init logs:
ssh ec2-user@<ip> "cat /var/log/cloud-init-output.log" | claude -p "explain why Ollama failed to start and suggest fixes"

# Check Ollama service status:
ssh ec2-user@<ip> "systemctl status ollama"

# If terraform plan fails:
terraform plan 2>&1 | claude -p "explain these terraform errors and fix them"
```

## Prerequisites

Before starting, you need:
- [ ] AWS account with billing alerts enabled
- [ ] AWS CLI configured with credentials
- [ ] Terraform >= 1.5 installed
- [ ] GitHub repo created with Actions enabled
- [ ] Claude Code installed (`npm install -g @anthropic-ai/claude-code`)

## Next Project (Level 2)

After completing this project, the next step is:
- Add a GPU instance option (g5.xlarge) for faster inference with larger models
- Migrate from EC2 to EKS (Kubernetes)
- Add autoscaling, monitoring (Prometheus + Grafana), and API Gateway
- Implement proper networking (private subnets, NAT, ALB)
