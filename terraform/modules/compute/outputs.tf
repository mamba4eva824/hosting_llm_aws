output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.ollama.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ollama.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.ollama.public_dns
}

output "ollama_api_url" {
  description = "URL for the Ollama API"
  value       = "http://${aws_instance.ollama.public_ip}:11434"
}
