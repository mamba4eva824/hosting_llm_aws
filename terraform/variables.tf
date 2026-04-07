variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "ollama-learning"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet"
  type        = string
  default     = "us-west-1a"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into instances"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_api_cidr" {
  description = "CIDR block allowed to access the Ollama API (port 11434)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge"
}

variable "key_name" {
  description = "SSH key pair name for instance access"
  type        = string
  default     = null
}

variable "use_spot" {
  description = "Use a spot instance instead of on-demand"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB"
  type        = number
  default     = 30
}
