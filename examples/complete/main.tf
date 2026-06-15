# ---------------------------------------------------------------------------
# Provider block — CI-friendly skip flags + non-AWS-shaped placeholder creds.
# ---------------------------------------------------------------------------
provider "aws" {
  region                      = "ap-south-1"
  access_key                  = "not-a-real-aws-key"
  secret_key                  = "not-a-real-aws-secret"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Uses local path during development.
# Change to Registry source after first release:
#   source  = "devotica-labs/rds/aws"
#   version = "~> 0.1"

module "rds" {
  source = "../.."

  identifier     = "devotica-prod-payments"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.m7g.large"

  # Storage with autoscaling headroom.
  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  iops                  = 12000
  storage_throughput    = 500

  # Workload KMS key (typically from devotica-labs/terraform-aws-kms).
  kms_key_arn = "arn:aws:kms:ap-south-1:111122223333:key/00000000-0000-0000-0000-000000000000"

  # AWS-managed master password — default. Caller doesn't see the secret.
  # The KMS key the secret is encrypted under defaults to kms_key_arn.
  manage_master_user_password = true

  # Database
  db_name  = "payments"
  username = "payments_admin"

  # Networking
  db_subnet_group_name   = "devotica-prod-private-db"
  vpc_security_group_ids = ["sg-0aaaaaaaaaaaaaaaa", "sg-0bbbbbbbbbbbbbbbb"]
  port                   = 5432

  # HA + backups (fintech defaults are already on; restating for the example)
  multi_az                         = true
  backup_retention_period          = 35
  backup_window                    = "18:00-19:00"
  copy_tags_to_snapshot            = true
  deletion_protection              = true
  skip_final_snapshot              = false
  final_snapshot_identifier_prefix = "final"

  # Maintenance
  maintenance_window         = "sun:19:00-sun:20:00"
  auto_minor_version_upgrade = true
  apply_immediately          = false

  # Monitoring — Enhanced + PI both on for prod
  monitoring_interval                   = 60
  performance_insights_enabled          = true
  performance_insights_retention_period = 31

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Auth
  iam_database_authentication_enabled = true

  # Custom parameter group — Postgres tuning
  parameter_group_family = "postgres16"
  parameters = [
    { name = "log_min_duration_statement", value = "1000" },
    { name = "log_connections", value = "1" },
    { name = "log_disconnections", value = "1" },
    { name = "pg_stat_statements.track", value = "ALL" },
    # shared_preload_libraries requires pending-reboot apply
    { name = "shared_preload_libraries", value = "pg_stat_statements", apply_method = "pending-reboot" },
  ]

  tags = {
    Environment = "production"
    Project     = "payments"
    Owner       = "data-platform@devotica.com"
    CostCenter  = "PAYMENTS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-rds"
  }
}
