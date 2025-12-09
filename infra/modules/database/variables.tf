variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block of the VPC"
}

variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs for the database"
}

variable "snapshot_identifier" {
  description = "The ID of the snapshot to restore from. If null, creates a new DB."
  type        = string
  default     = null
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}
