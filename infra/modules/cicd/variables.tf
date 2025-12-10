variable "bucket_id" {
  description = "ID of the S3 bucket for artifacts"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket for artifacts"
  type        = string
}

variable "base_repo_url" {
  description = "URL of the base ECR repository"
  type        = string
}
