output "db_instance_id" {
  description = "RDS instance identifier."
  value       = module.rds.db_instance_id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = module.rds.db_instance_arn
}

output "db_endpoint" {
  description = "Connection endpoint (host:port)."
  value       = module.rds.db_instance_endpoint
}

output "db_resource_id" {
  description = "Immutable RDS resource ID (dbi-...). Used in IAM database-auth policy conditions."
  value       = module.rds.db_instance_resource_id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the master password (AWS-managed)."
  value       = module.rds.master_user_secret_arn
}

output "enhanced_monitoring_role_arn" {
  description = "ARN of the enhanced-monitoring IAM role."
  value       = module.rds.enhanced_monitoring_role_arn
}

output "parameter_group_name" {
  description = "Name of the parameter group attached to the instance."
  value       = module.rds.parameter_group_name
}
