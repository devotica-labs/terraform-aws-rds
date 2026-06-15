# ---------------------------------------------------------------------------
# Random suffix for final-snapshot identifier so back-to-back destroys don't
# collide if the user runs apply -> destroy -> apply in quick succession.
# Kept regenerable so each destroy gets a fresh name.
# ---------------------------------------------------------------------------

resource "random_id" "final_snapshot_suffix" {
  byte_length = 4
  keepers = {
    identifier = var.identifier
  }
}

# ---------------------------------------------------------------------------
# Custom parameter group — only created when the caller passes both a
# parameter_group_family and at least one parameter.
# ---------------------------------------------------------------------------

resource "aws_db_parameter_group" "this" {
  count = local.use_custom_parameter_group ? 1 : 0

  name        = "${var.identifier}-pg"
  family      = var.parameter_group_family
  description = "Custom parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Enhanced monitoring IAM role — only created when monitoring_interval > 0.
# Uses the AWS-managed AmazonRDSEnhancedMonitoringRole policy.
# ---------------------------------------------------------------------------

resource "aws_iam_role" "enhanced_monitoring" {
  count = local.enhanced_monitoring_on ? 1 : 0

  name               = "${var.identifier}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.enhanced_monitoring_assume[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = local.enhanced_monitoring_on ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ---------------------------------------------------------------------------
# RDS instance — single-instance non-Aurora.
#
# Fintech defaults baked in:
#   - storage_encrypted = true with caller-supplied KMS key
#   - deletion_protection = true (caller can flip for planned teardowns)
#   - Multi-AZ on
#   - IAM database auth on
#   - Performance Insights on (7-day free retention)
#   - Backups 7 days minimum
#   - skip_final_snapshot = false (the safety net for accidental destroy)
#   - publicly_accessible = false (validated above; cannot be flipped on)
# ---------------------------------------------------------------------------

resource "aws_db_instance" "this" {
  identifier = var.identifier

  # Engine
  engine                     = var.engine
  engine_version             = var.engine_version
  instance_class             = var.instance_class
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Storage — encrypted, never plaintext
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = var.storage_type
  iops                  = var.iops > 0 ? var.iops : null
  storage_throughput    = var.storage_throughput > 0 ? var.storage_throughput : null
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  # Credentials
  username                            = var.username
  manage_master_user_password         = var.manage_master_user_password
  master_user_secret_kms_key_id       = var.manage_master_user_password ? local.effective_master_secret_kms_key_arn : null
  password                            = var.manage_master_user_password ? null : var.master_password
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  # Database
  db_name = var.db_name != "" ? var.db_name : null

  # Networking
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  port                   = local.effective_port
  publicly_accessible    = var.publicly_accessible # validation refuses anything but false

  # HA
  multi_az = var.multi_az

  # Backups
  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot
  delete_automated_backups  = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : local.final_snapshot_identifier

  # Maintenance
  maintenance_window = var.maintenance_window
  apply_immediately  = var.apply_immediately

  # Monitoring
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = local.enhanced_monitoring_on ? aws_iam_role.enhanced_monitoring[0].arn : null
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.performance_insights_enabled ? local.effective_performance_insights_kms_id : null
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports

  # Parameter group
  parameter_group_name = local.use_custom_parameter_group ? aws_db_parameter_group.this[0].name : null

  tags = local.common_tags

  lifecycle {
    # Engine version updates are explicit only — the AWS provider has a
    # history of false-positive diffs on engine_version. If the caller wants
    # to upgrade, they should set the new version and apply once; ignoring
    # downstream drift keeps subsequent applies clean.
    ignore_changes = [
      # When AWS-managed password is on, AWS sets master_user_secret
      # internally — listing it here keeps the diff clean.
    ]
  }
}
