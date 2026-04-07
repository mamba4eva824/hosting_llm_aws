locals {
  common_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

# --- VPC ---

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# --- Public Subnet ---

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public"
  })
}

# --- Internet Gateway ---

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# --- Route Table ---

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# --- Security Group ---

resource "aws_security_group" "ollama" {
  name        = "${var.project_name}-ollama-sg"
  description = "Allow SSH and Ollama API access"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ollama-sg"
  })
}

# Ingress: SSH
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ollama.id
  description       = "SSH access"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Ingress: Ollama API
resource "aws_vpc_security_group_ingress_rule" "ollama_api" {
  security_group_id = aws_security_group.ollama.id
  description       = "Ollama API access"
  cidr_ipv4         = var.allowed_api_cidr
  from_port         = 11434
  to_port           = 11434
  ip_protocol       = "tcp"
}

# Egress: allow all outbound
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ollama.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
