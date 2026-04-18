# Ollama on EC2 — Self-Hosted LLM Inference

Deploy a **Docker** image on EC2: **FastAPI** (port **5000**) proxies to **Ollama** inside the same container (Ollama on **11434** is not exposed on the host). Infrastructure is Terraform; images live in **ECR**.

## Architecture

```
┌──────────────── AWS VPC (us-west-1) ──────────────────┐
│                                                      │
│   Public Subnet (10.0.1.0/24, us-west-1a)           │
│   ┌──────────────────────────────────────────┐       │
│   │  EC2 · Amazon Linux 2023 · Docker        │       │
│   │  Container: FastAPI :5000 → Ollama     │       │
│   │  (gemma2:2b pulled in container)         │       │
│   └──────────────────────────────────────────┘       │
│                                                      │
│   Security Group: SSH (22), FastAPI (5000)          │
│   ECR: inference image (build + push from dev)     │
└──────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS account with billing alerts enabled
- AWS CLI configured with credentials
- Terraform >= 1.5
- GitHub repo with Actions enabled

## Quick Start

1. **Create infrastructure and the empty ECR repository**

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values (e.g. key_name, allowed_*_cidr)

terraform init
terraform apply -var-file=terraform.tfvars
```

2. **Build and push the inference image** (from the repo root)

```bash
chmod +x scripts/push-inference-image.sh
./scripts/push-inference-image.sh
```

3. **If the EC2 instance already started before step 2**, replace it so `user_data` pulls the image:

```bash
cd terraform
terraform apply -replace='module.compute.aws_instance.ollama' -var-file=terraform.tfvars
```

Optional: set `inference_image` in `terraform.tfvars` to a full URI (e.g. another registry). Otherwise the default is the project ECR URL with the `latest` tag.

## Test the API

```bash
# Health (FastAPI → Ollama)
curl http://$(terraform output -raw instance_public_ip):5000/health

# Chat completion (OpenAI-compatible, proxied to Ollama)
curl http://$(terraform output -raw instance_public_ip):5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'

# Or use ./scripts/test-endpoint.sh
```

## Branching Strategy

This project uses a **dev → main** workflow with CI/CD gates:

```
feature/*  ──┐
bugfix/*   ──┼──► dev ──── PR ────► main
docs/*     ──┘     │                  │
                   │                  │
              terraform plan     terraform apply
              (on PR open)       (on merge)
```

### Workflow

1. **Create a branch** off `dev` for your work (e.g., `feature/add-cloudwatch-alarms`)
2. **Push and open a PR** into `dev` for team review
3. **Merge to dev** after approval
4. **Open a PR from `dev` to `main`** — this triggers `terraform plan` and posts the plan as a PR comment
5. **Review the plan**, then merge — this triggers `terraform apply` with auto-approve

### Branch Rules

| Branch | Purpose | Deploys? |
|---|---|---|
| `main` | Production infrastructure state | Yes — `terraform apply` on merge |
| `dev` | Integration branch for testing | No — plan only |
| `feature/*`, `bugfix/*`, `docs/*` | Short-lived work branches | No |

### GitHub Branch Protection Settings

Configure these in **Settings → Branches → Branch protection rules**:

#### `main` branch

| Setting | Value |
|---|---|
| Require a pull request before merging | Enabled |
| Require approvals | 1 (or more for teams) |
| Dismiss stale pull request approvals when new commits are pushed | Enabled |
| Require status checks to pass before merging | Enabled |
| Required status checks | `terraform-plan` |
| Require branches to be up to date before merging | Enabled |
| Restrict who can push to matching branches | Enabled — only via PR |
| Do not allow bypassing the above settings | Enabled |
| Allow force pushes | Disabled |
| Allow deletions | Disabled |

#### `dev` branch

| Setting | Value |
|---|---|
| Require a pull request before merging | Enabled |
| Require approvals | 1 (optional for solo projects) |
| Allow force pushes | Disabled |
| Allow deletions | Disabled |

### Setting Up Branch Protection via CLI

```bash
# Create dev branch
git checkout -b dev
git push -u origin dev

# Protect main
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["terraform-plan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF

# Protect dev
gh api repos/{owner}/{repo}/branches/dev/protection \
  --method PUT \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF
```

## Cost Estimate

| Component | Monthly (24/7) | Daily (8hr) |
|---|---|---|
| t3.xlarge on-demand | ~$122 | ~$1.36 |
| 30 GiB gp3 EBS | ~$2.40 | ~$2.40 |
| **Total** | **~$125** | **~$44** |

Cost protection (Phase 3): nightly shutdown cron, $50 billing alarm, 8hr uptime alarm.

## Teardown

```bash
cd terraform
terraform destroy -var-file=terraform.tfvars
```

## Project Structure

```
├── inference/                  # Dockerfile, FastAPI app, docker-compose (local)
├── terraform/
│   ├── main.tf                 # Provider + module wiring
│   ├── ecr.tf                  # ECR repository for the inference image
│   ├── variables.tf            # Root inputs
│   ├── outputs.tf              # Instance IP, ECR URL, app URL
│   ├── modules/
│   │   ├── networking/         # VPC, subnet, IGW, SG (5000 + 22)
│   │   └── compute/            # EC2, IAM, user_data (docker pull + run)
├── scripts/                    # push-inference-image.sh, test-endpoint.sh, …
├── .github/workflows/          # CI/CD pipelines (stubs)
└── docs/                       # Architecture + build logs
```
