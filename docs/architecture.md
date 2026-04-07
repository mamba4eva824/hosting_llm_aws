# Architecture Overview

## Summary

Self-hosted LLM inference using Ollama on a single EC2 instance in AWS, provisioned entirely with Terraform. The architecture prioritizes simplicity and cost-safety over production hardening.

## Infrastructure Diagram

```
                    ┌──────────────────────────────────────────┐
                    │              AWS (us-west-1)             │
                    │                                          │
                    │  ┌──────────── VPC 10.0.0.0/16 ───────┐ │
                    │  │                                     │ │
                    │  │  Public Subnet 10.0.1.0/24          │ │
                    │  │  (us-west-1a)                       │ │
                    │  │                                     │ │
                    │  │  ┌───────────────────────────────┐  │ │
                    │  │  │  EC2 t3.xlarge                │  │ │
                    │  │  │  Amazon Linux 2023            │  │ │
                    │  │  │  30 GiB gp3 root volume      │  │ │
                    │  │  │                               │  │ │
                    │  │  │  ┌─────────────────────────┐  │  │ │
                    │  │  │  │  Ollama (systemd)       │  │  │ │
                    │  │  │  │  gemma2:2b model        │  │  │ │
                    │  │  │  │  0.0.0.0:11434          │  │  │ │
                    │  │  │  └─────────────────────────┘  │  │ │
                    │  │  └───────────────────────────────┘  │ │
                    │  │                                     │ │
                    │  │  Internet Gateway ◄──► Route Table  │ │
                    │  │                                     │ │
                    │  └─────────────────────────────────────┘ │
                    │                                          │
                    │  Security Group                          │
                    │  ├─ Ingress: TCP 22    (allowed_ssh_cidr)│
                    │  ├─ Ingress: TCP 11434 (allowed_api_cidr)│
                    │  └─ Egress:  All       (0.0.0.0/0)      │
                    │                                          │
                    │  IAM Role + Instance Profile             │
                    │  └─ AmazonSSMManagedInstanceCore         │
                    └──────────────────────────────────────────┘
```

## Terraform Module Structure

```
terraform/
├── main.tf              # Provider config, wires modules together
├── variables.tf         # Root-level input variables
├── outputs.tf           # instance_id, instance_public_ip, ollama_api_url
├── terraform.tfvars.example
├── backend.tf           # S3 remote state (not yet configured)
├── data.tf              # Placeholder for shared data sources
└── modules/
    ├── networking/       # VPC, subnet, IGW, route table, security group
    └── compute/          # EC2 instance, IAM role/profile, user_data.sh
```

### Module: networking

Creates the network layer. All resources are tagged with project name and `ManagedBy = "terraform"`.

| Resource | Purpose |
|---|---|
| `aws_vpc` | VPC with DNS support and hostnames enabled |
| `aws_subnet` | Single public subnet with auto-assign public IP |
| `aws_internet_gateway` | Internet access for the subnet |
| `aws_route_table` | Routes 0.0.0.0/0 through the IGW |
| `aws_route_table_association` | Binds route table to subnet |
| `aws_security_group` | Container for ingress/egress rules |
| `aws_vpc_security_group_ingress_rule` (x2) | SSH (22) and Ollama API (11434) |
| `aws_vpc_security_group_egress_rule` | All outbound traffic |

Security group rules use standalone resources (not inline blocks) per current Terraform best practice.

### Module: compute

Creates the EC2 instance with Ollama bootstrapped via cloud-init.

| Resource | Purpose |
|---|---|
| `data.aws_ami` | Looks up latest Amazon Linux 2023 x86_64 AMI |
| `aws_iam_role` | EC2 assume-role for instance profile |
| `aws_iam_role_policy_attachment` | SSM access for Session Manager |
| `aws_iam_instance_profile` | Attaches role to instance |
| `aws_instance` | t3.xlarge with user_data bootstrap, gp3 volume, IMDSv2 required |

**user_data.sh bootstrap order:**
1. Install Ollama via official installer
2. Create systemd override: `OLLAMA_HOST=0.0.0.0`
3. Enable and start Ollama service
4. Wait for health check (up to 30s)
5. Pull gemma2:2b model

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Ollama over NVIDIA NIM | Simpler — single binary, no Docker, no NGC account, no API keys |
| CPU (t3.xlarge) over GPU (g5.xlarge) | ~$0.17/hr vs ~$1.01/hr, no GPU quota needed, sufficient for small models |
| gemma2:2b model | Small enough for CPU inference (~5-10 tok/s), fits in 16GB RAM |
| Single public subnet | Learning project — no need for NAT/private subnets |
| Standalone SG rules | Current Terraform best practice, avoids issues with inline rules |
| IMDSv2 required | Security best practice — blocks IMDSv1 token-less requests |
| prevent_destroy lifecycle | Safety net against accidental `terraform destroy` |
| Spot instance toggle | Variable `use_spot` defaults to false, can reduce cost further |

## Network Access

- **SSH**: Port 22, restricted by `allowed_ssh_cidr` variable
- **Ollama API**: Port 11434, restricted by `allowed_api_cidr` variable
- **Note**: Ollama has no built-in authentication — restrict API CIDR to your IP in production

## Cost Estimate

| Component | Monthly (24/7) | Daily (8hr) |
|---|---|---|
| t3.xlarge on-demand | ~$122 | ~$1.36 |
| 30 GiB gp3 EBS | ~$2.40 | ~$2.40 |
| Data transfer (minimal) | ~$1 | ~$1 |
| **Total** | **~$126** | **~$45** |

Cost protection measures (Phase 3): nightly shutdown cron, billing alarm at $50, uptime alarm at 8hr.
