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

output "ollama_api_url" {
  description = "URL for the Ollama API"
  value       = module.compute.ollama_api_url
}
