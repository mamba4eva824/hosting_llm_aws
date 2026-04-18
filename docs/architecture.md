# Architecture Overview

## Summary

Self-hosted LLM inference using **Docker on EC2**: a container runs **Ollama** and **FastAPI** (FastAPI on port **5000** is the public API; Ollama stays on **11434** inside the container). Terraform provisions VPC, EC2, IAM, and **ECR** for the image. The architecture prioritizes simplicity and cost-safety over production hardening.

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
                    │  │  │  │  Docker: FastAPI :5000 │  │  │ │
                    │  │  │  │  → Ollama :11434       │  │  │ │
                    │  │  │  │  (gemma2:2b)           │  │  │ │
                    │  │  │  └─────────────────────────┘  │  │ │
                    │  │  └───────────────────────────────┘  │ │
                    │  │                                     │ │
                    │  │  Internet Gateway ◄──► Route Table  │ │
                    │  │                                     │ │
                    │  └─────────────────────────────────────┘ │
                    │                                          │
                    │  Security Group                          │
                    │  ├─ Ingress: TCP 22    (allowed_ssh_cidr)│
                    │  ├─ Ingress: TCP 5000 (allowed_api_cidr)  │
                    │  └─ Egress:  All       (0.0.0.0/0)      │
                    │                                          │
                    │  IAM Role + Instance Profile             │
                    │  ├─ AmazonSSMManagedInstanceCore         │
                    │  └─ AmazonEC2ContainerRegistryReadOnly   │
                    └──────────────────────────────────────────┘
```

## Terraform Module Structure

```
terraform/
├── main.tf              # Provider config, wires modules together
├── variables.tf         # Root-level input variables
├── ecr.tf               # ECR repository for inference image
├── outputs.tf           # instance_id, instance_public_ip, ecr_repository_url, inference_app_url
├── terraform.tfvars.example
├── backend.tf           # S3 remote state (not yet configured)
├── data.tf              # Placeholder for shared data sources
└── modules/
    ├── networking/       # VPC, subnet, IGW, route table, security group
    └── compute/          # EC2 instance, IAM role/profile, user_data (docker pull + run)
```

### Module: networking

Creates the network layer. All resources are tagged with project name and `ManagedBy = "terraform"`.


| Resource                                   | Purpose                                         |
| ------------------------------------------ | ----------------------------------------------- |
| `aws_vpc`                                  | VPC with DNS support and hostnames enabled      |
| `aws_subnet`                               | Single public subnet with auto-assign public IP |
| `aws_internet_gateway`                     | Internet access for the subnet                  |
| `aws_route_table`                          | Routes 0.0.0.0/0 through the IGW                |
| `aws_route_table_association`              | Binds route table to subnet                     |
| `aws_security_group`                       | Container for ingress/egress rules              |
| `aws_vpc_security_group_ingress_rule` (x2) | SSH (22) and FastAPI (5000)                     |
| `aws_vpc_security_group_egress_rule`       | All outbound traffic                            |


Security group rules use standalone resources (not inline blocks) per current Terraform best practice.

### Module: compute

Creates the EC2 instance; cloud-init installs Docker, logs in to ECR when the image URI is an ECR URL, pulls the inference image, and runs the container.


| Resource                         | Purpose                                                         |
| -------------------------------- | --------------------------------------------------------------- |
| `data.aws_ami`                   | Looks up latest Amazon Linux 2023 x86_64 AMI                    |
| `aws_iam_role`                   | EC2 assume-role for instance profile                            |
| `aws_iam_role_policy_attachment` | SSM access for Session Manager                                  |
| `aws_iam_role_policy_attachment` | ECR read-only (pull images)                                     |
| `aws_iam_instance_profile`       | Attaches role to instance                                       |
| `aws_instance`                   | t3.xlarge with user_data bootstrap, gp3 volume, IMDSv2 required |


**user_data bootstrap order:**

1. Install Docker and AWS CLI (for ECR login)
2. Optionally `docker login` to ECR
3. `docker pull` the configured image
4. `docker run` with port **5000** published (FastAPI; Ollama is not published to the host)

## Key Design Decisions


| Decision                             | Rationale                                                                |
| ------------------------------------ | ------------------------------------------------------------------------ |
| Ollama in Docker + FastAPI           | API boundary on 5000; ECR for images; path to ECS later                  |
| CPU (t3.xlarge) over GPU (g5.xlarge) | ~$0.17/hr vs ~$1.01/hr, no GPU quota needed, sufficient for small models |
| gemma2:2b model                      | Small enough for CPU inference (~5-10 tok/s), fits in 16GB RAM           |
| Single public subnet                 | Learning project — no need for NAT/private subnets                       |
| Standalone SG rules                  | Current Terraform best practice, avoids issues with inline rules         |
| IMDSv2 required                      | Security best practice — blocks IMDSv1 token-less requests               |
| prevent_destroy lifecycle            | Safety net against accidental `terraform destroy`                        |
| Spot instance toggle                 | Variable `use_spot` defaults to false, can reduce cost further           |


## Network Access

- **SSH**: Port 22, restricted by `allowed_ssh_cidr` variable
- **FastAPI (inference)**: Port 5000, restricted by `allowed_api_cidr` variable (Ollama is only reachable inside the container)
- **Note**: Add auth at the app or gateway layer for production; restrict `allowed_api_cidr` to your IP while learning

## Cost Estimate


| Component               | Monthly (24/7) | Daily (8hr) |
| ----------------------- | -------------- | ----------- |
| t3.xlarge on-demand     | ~$122          | ~$1.36      |
| 30 GiB gp3 EBS          | ~$2.40         | ~$2.40      |
| Data transfer (minimal) | ~$1            | ~$1         |
| **Total**               | **~$126**      | **~$45**    |


Cost protection measures (Phase 3): nightly shutdown cron, billing alarm at $50, uptime alarm at 8hr.