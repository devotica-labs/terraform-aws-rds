output "db_endpoint" {
  description = "Connection endpoint (host:port)."
  value       = module.rds.db_instance_endpoint
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN holding the master password (AWS-managed)."
  value       = module.rds.master_user_secret_arn
}
