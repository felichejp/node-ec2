variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "folders" {
  description = "List of folder keys to create"
  type        = list(string)
  default     = []
}
