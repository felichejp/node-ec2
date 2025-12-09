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

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs"
}
