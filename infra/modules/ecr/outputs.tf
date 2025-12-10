output "app_repo_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "base_repo_url" {
  value = aws_ecr_repository.base_repo.repository_url
}

output "app_repo_arn" {
  value = aws_ecr_repository.app_repo.arn
}

output "base_repo_arn" {
  value = aws_ecr_repository.base_repo.arn
}


