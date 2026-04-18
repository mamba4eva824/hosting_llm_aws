output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "security_group_id" {
  description = "ID of the Ollama security group"
  value       = module.networking.security_group_id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.compute.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.compute.instance_public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for the inference image (build and push before first instance boot, or re-run user_data)"
  value       = aws_ecr_repository.inference.repository_url
}

output "inference_app_url" {
  description = "URL for FastAPI (proxies to Ollama in the container)"
  value       = module.compute.inference_app_url
}
