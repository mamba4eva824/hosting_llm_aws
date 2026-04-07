# Phase 1 Build Log — Scaffold

**Date**: 2026-04-06
**Goal**: Create Terraform directory structure and modules for networking and compute.

## Scope Changes from Original CLAUDE.md

The project was originally specced for NVIDIA NIM on a GPU instance. During Phase 1 we simplified:

| Original | Changed To | Why |
|---|---|---|
| NVIDIA NIM container | Ollama (native binary) | No Docker, no NGC account, no API keys — much less complexity |
| g5.xlarge (A10G GPU) | t3.xlarge (CPU) | ~6x cheaper, no GPU quota needed, sufficient for small models |
| meta/llama3-8b-instruct | gemma2:2b | Small enough for CPU inference, fits in 16GB RAM |
| Port 8000 | Port 11434 | Ollama default port |
| us-east-1 | us-west-1 | User preference |
| NVIDIA GPU-optimized AMI | Amazon Linux 2023 | No GPU drivers needed for CPU instance |

The CLAUDE.md was rewritten to reflect these changes.

## What Was Built

### Step 1: Directory Structure

Created the full project scaffold:

```
model_hosting_aws/
├── CLAUDE.md
├── .gitignore
├── terraform/
│   ├── main.tf, variables.tf, outputs.tf
│   ├── terraform.tfvars.example
│   ├── backend.tf, data.tf
│   └── modules/
│       ├── networking/  (main.tf, variables.tf, outputs.tf)
│       └── compute/     (main.tf, variables.tf, outputs.tf, user_data.sh)
├── scripts/             (shutdown.sh, startup.sh, test-endpoint.sh)
├── .github/workflows/   (plan.yml, apply.yml, nightly-shutdown.yml)
├── dev/active/          (context.md)
└── docs/                (this file)
```

### Step 2: Networking Module

Used the Terraform MCP server to fetch latest AWS provider docs (v6.39.0).

**Resources created:**
- VPC (10.0.0.0/16) with DNS support and hostnames
- Public subnet (10.0.1.0/24) in us-west-1a with auto-assign public IP
- Internet gateway attached to VPC
- Route table with 0.0.0.0/0 → IGW, associated to subnet
- Security group with standalone ingress/egress rules:
  - TCP 22 (SSH) — restricted by `allowed_ssh_cidr`
  - TCP 11434 (Ollama API) — restricted by `allowed_api_cidr`
  - All outbound

**Design note**: Used `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` standalone resources instead of inline `ingress`/`egress` blocks. This is the current Terraform best practice per the provider docs.

**Security feedback applied**: Added `allowed_api_cidr` variable (defaults to 0.0.0.0/0) to allow locking down the Ollama API port to a specific IP, since Ollama has no built-in auth.

### Step 3: Compute Module

**Resources created:**
- AMI data source — latest Amazon Linux 2023 x86_64
- IAM role with EC2 assume-role policy
- SSM managed policy attachment (for Session Manager access)
- IAM instance profile
- EC2 instance (t3.xlarge):
  - 30 GiB gp3 root volume
  - IMDSv2 required (security best practice)
  - `prevent_destroy` lifecycle rule
  - Optional spot instance via `use_spot` variable
  - `user_data.sh` bootstraps Ollama

**user_data.sh** bootstrap sequence:
1. Install Ollama via `curl -fsSL https://ollama.com/install.sh | sh`
2. Create systemd override setting `OLLAMA_HOST=0.0.0.0`
3. Enable + restart Ollama service
4. Wait for health check (polls localhost:11434 up to 30s)
5. Pull gemma2:2b model

Ollama runs as a systemd service — it starts on boot and survives reboots.

### Step 4: Root Module Wiring

- `main.tf` — AWS provider pinned to ~> 6.39, wires networking and compute modules
- `variables.tf` — All configurable inputs with sensible defaults
- `outputs.tf` — vpc_id, subnet_id, security_group_id, instance_id, instance_public_ip, ollama_api_url
- `terraform.tfvars.example` — Documented example values

### Validation

Ran `terraform init`, `terraform fmt -recursive`, and `terraform validate` after each module was created. All passed.

## Remaining Placeholder Files

These files exist but have not been implemented yet:

- `terraform/backend.tf` — S3 remote state (Phase 2 or 3)
- `terraform/data.tf` — Shared data sources (AMI lookup moved into compute module)
- `scripts/shutdown.sh`, `startup.sh`, `test-endpoint.sh` — Phase 3
- `.github/workflows/plan.yml`, `apply.yml`, `nightly-shutdown.yml` — Phase 2

## What's Next (Phase 2 — CI/CD)

1. GitHub Actions workflow for PRs: fmt check, validate, plan with PR comment
2. GitHub Actions workflow for merges to main: auto-apply
3. Nightly shutdown cron workflow
