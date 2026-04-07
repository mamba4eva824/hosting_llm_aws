# Ollama on EC2 — Self-Hosted LLM Inference

Deploy Ollama serving Gemma 2B on a CPU-based EC2 instance in AWS, fully managed with Terraform and automated via GitHub Actions CI/CD.

## Architecture

```
┌──────────────── AWS VPC (us-west-1) ────────────────┐
│                                                      │
│   Public Subnet (10.0.1.0/24, us-west-1a)           │
│   ┌──────────────────────────────────────────┐       │
│   │  EC2 t3.xlarge · Amazon Linux 2023       │       │
│   │  Ollama (systemd) · gemma2:2b            │       │
│   │  Port 11434                              │       │
│   └──────────────────────────────────────────┘       │
│                                                      │
│   Security Group: SSH (22), Ollama API (11434)       │
└──────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS account with billing alerts enabled
- AWS CLI configured with credentials
- Terraform >= 1.5
- GitHub repo with Actions enabled

## Quick Start

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Test the API

```bash
# Health check
curl http://$(terraform output -raw instance_public_ip):11434/

# Chat completion (OpenAI-compatible)
curl http://$(terraform output -raw instance_public_ip):11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemma2:2b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 100
  }'
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
├── terraform/
│   ├── main.tf                 # Provider + module wiring
│   ├── variables.tf            # Root inputs
│   ├── outputs.tf              # Instance IP, API URL
│   ├── modules/
│   │   ├── networking/         # VPC, subnet, IGW, SG
│   │   └── compute/            # EC2, IAM, user_data.sh
├── scripts/                    # Utility scripts
├── .github/workflows/          # CI/CD pipelines
└── docs/                       # Architecture + build logs
```
