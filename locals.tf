locals {
  common_tags = merge(
    { ManagedBy = "terraform", Module = "terraform-aws-rds" },
    var.tags
  )

  # Engine-aware defaults for ports the caller didn't override.
  default_port = (
    var.engine == "postgres" ? 5432 :
    var.engine == "mysql" ? 3306 :
    var.engine == "mariadb" ? 3306 :
    3306
  )
  effective_port = var.port != 0 ? var.port : local.default_port

  # KMS key reuse — the master-secret and PI keys default to the workload key.
  effective_master_secret_kms_key_arn   = var.master_user_secret_kms_key_arn != "" ? var.master_user_secret_kms_key_arn : var.kms_key_arn
  effective_performance_insights_kms_id = var.performance_insights_kms_key_arn != "" ? var.performance_insights_kms_key_arn : var.kms_key_arn

  # Custom parameter group is only created when the family is set AND at
  # least one parameter is provided. Otherwise the instance uses the AWS
  # default parameter group for the engine version.
  use_custom_parameter_group = var.parameter_group_family != "" && length(var.parameters) > 0

  # Enhanced monitoring requires an IAM role with the AWS-managed
  # AmazonRDSEnhancedMonitoringRole policy. Only create when on.
  enhanced_monitoring_on = var.monitoring_interval > 0

  # When destroying, identify the final snapshot so a re-create can find it.
  final_snapshot_identifier = "${var.final_snapshot_identifier_prefix}-${var.identifier}-${random_id.final_snapshot_suffix.hex}"
}
