variable "app_repo_name" {
  description = "Name of the application ECR repository"
  type        = string
  default     = "image-services"
}

variable "base_repo_name" {
  description = "Name of the base images ECR repository"
  type        = string
  default     = "image-base"
}


