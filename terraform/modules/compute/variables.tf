variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.xlarge"
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance in"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to attach to the instance"
  type        = string
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

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
