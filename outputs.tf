output "db_instance_id" {
  description = "RDS instance identifier (e.g. \"devotica-prod-payments\")."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "db_instance_address" {
  description = "Hostname of the RDS instance (without port)."
  value       = aws_db_instance.this.address
}

output "db_instance_endpoint" {
  description = "Connection endpoint in host:port form."
  value       = aws_db_instance.this.endpoint
}

output "db_instance_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_instance_resource_id" {
  description = "Immutable RDS resource ID (dbi-...). Used in IAM database-auth policy conditions and in CloudWatch resource ARNs."
  value       = aws_db_instance.this.resource_id
}

output "db_instance_name" {
  description = "Name of the initial database created. Empty string when var.db_name was unset."
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "Master username (defaults to \"dbadmin\")."
  value       = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "ARN of the AWS-managed Secrets Manager secret holding the master password. Empty string when manage_master_user_password = false."
  value       = var.manage_master_user_password ? aws_db_instance.this.master_user_secret[0].secret_arn : ""
}

output "parameter_group_name" {
  description = "Name of the parameter group attached to the instance. Empty string when using the AWS default."
  value       = local.use_custom_parameter_group ? aws_db_parameter_group.this[0].name : ""
}

output "enhanced_monitoring_role_arn" {
  description = "ARN of the enhanced-monitoring IAM role. Empty string when monitoring_interval = 0."
  value       = local.enhanced_monitoring_on ? aws_iam_role.enhanced_monitoring[0].arn : ""
}

output "final_snapshot_identifier" {
  description = "Identifier of the final snapshot that would be taken on destroy. Empty string when skip_final_snapshot = true."
  value       = var.skip_final_snapshot ? "" : local.final_snapshot_identifier
}
