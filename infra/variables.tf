variable "instance_name" {
  type        = string
  description = "The name of the instance"
  default     = "terraform-example-arm64"
}

variable "instance_type" {
  type        = string
  description = "The type of the instance"
  default     = "t4g.nano"
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
  default     = "eks-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}

variable "public_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets"
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
}

variable "database_subnets" {
  type        = list(string)
  description = "List of CIDR blocks for database subnets"
  default     = ["10.0.201.0/24", "10.0.202.0/24"]
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  default     = "ChangeMe123!" # In real use, provide this via environment variable
  sensitive   = true
}

variable "snapshot_identifier" {
  description = "The ID of the snapshot to restore from. If null, creates a new DB."
  type        = string
  default     = "postgres-db1-snapshot-final"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "node-ec2-cicd-assets-feliche"
}

variable "folders" {
  description = "List of folder keys to create"
  type        = list(string)
  default     = ["images/", "logs/"]
}
