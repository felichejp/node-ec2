output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnets
}

# output "db_endpoint" {
#   description = "The connection endpoint for the database"
#   value       = module.database.db_instance_endpoint
# }

# output "ec2_public_ip" {
#   description = "The public IP of the EC2 instance"
#   value       = module.compute.instance_public_ip
# }

output "ecr_repo_url" {
  description = "The URL of the ECR repository"
  value       = module.cicd.ecr_repository_url
}
