output "db_instance_endpoint" {
  description = "The connection endpoint"
  value       = module.db.db_instance_endpoint
}

output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = module.db.db_instance_address
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = module.security_group.security_group_id
}

