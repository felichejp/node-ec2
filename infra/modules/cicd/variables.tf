variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "folders" {
  description = "List of folder keys to create"
  type        = list(string)
  default     = ["images/", "logs/"]
}
