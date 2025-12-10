output "pipeline_arn" {
  value = aws_codepipeline.pipeline.arn
}

output "codebuild_project_name" {
  value = aws_codebuild_project.this.name
}
