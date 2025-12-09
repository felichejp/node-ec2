variable "instance_name" {
  type        = string
  description = "The name of the instance"
}

variable "instance_type" {
  type        = string
  description = "The type of the instance"
}

variable "subnet_id" {
  type        = string
  description = "The subnet ID to launch the instance in"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the security group will be created"
}

variable "custom_ami_id" {
  type        = string
  default     = ""
  description = "Optional custom AMI ID. If provided, this AMI will be used instead of the default Amazon Linux 2023 AMI"
}
