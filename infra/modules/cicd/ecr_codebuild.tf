# ECR Repository for CodeBuild-Buildah image
resource "aws_ecr_repository" "codebuild_buildah_repo" {
  name                 = "codebuild-buildah"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "production"
    Type        = "codebuild-image"
    TERRAFORM   = "true"
  }
}

resource "aws_ecr_lifecycle_policy" "codebuild_buildah_policy" {
  repository = aws_ecr_repository.codebuild_buildah_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
