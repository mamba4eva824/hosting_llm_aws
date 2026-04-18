terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  inference_image = coalesce(var.inference_image, "${aws_ecr_repository.inference.repository_url}:latest")
}

module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
  allowed_ssh_cidr   = var.allowed_ssh_cidr
  allowed_api_cidr   = var.allowed_api_cidr

  tags = {
    Environment = "dev"
  }
}

module "compute" {
  source = "./modules/compute"

  project_name      = var.project_name
  instance_type     = var.instance_type
  subnet_id         = module.networking.public_subnet_id
  security_group_id = module.networking.security_group_id
  key_name          = var.key_name
  use_spot          = var.use_spot
  root_volume_size  = var.root_volume_size
  aws_region        = var.aws_region
  inference_image   = local.inference_image
  ollama_model      = var.ollama_model

  tags = {
    Environment = "dev"
  }

  depends_on = [aws_ecr_repository.inference]
}
