# ---------------------------------------------------------------------------
# Core identity
# ---------------------------------------------------------------------------

variable "identifier" {
  description = "DB instance identifier. Globally unique within the account/region. Used for the resource name and (when manage_master_user_password = true) the AWS-managed secret's path."
  type        = string
  validation {
    condition     = length(var.identifier) >= 1 && length(var.identifier) <= 63 && can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.identifier))
    error_message = "identifier must be 1-63 chars, lowercase alphanumeric and hyphens, starting with a letter, not ending in a hyphen."
  }
}

# ---------------------------------------------------------------------------
# Engine
# ---------------------------------------------------------------------------

variable "engine" {
  description = "Database engine. Supported in v0.1: postgres, mysql. (Aurora variants live in a sister module — single-instance Aurora is an antipattern.)"
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql", "mariadb"], var.engine)
    error_message = "engine must be one of: postgres, mysql, mariadb."
  }
}

variable "engine_version" {
  description = "Engine major.minor (e.g. \"16.4\" for Postgres, \"8.0.39\" for MySQL). Must match a version AWS currently supports for the engine. Leave to the module default to track Postgres 16 LTS; pin explicitly in prod."
  type        = string
  default     = "16.4"
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t4g.medium for dev, db.m7g.large for prod). See AWS docs for the full list."
  type        = string
}

# ---------------------------------------------------------------------------
# Storage — encryption is non-negotiable (RBI / DPDP / PCI / SOC2).
# ---------------------------------------------------------------------------

variable "allocated_storage" {
  description = "Allocated storage in GB. Minimum 20 (Postgres) / 20 (MySQL)."
  type        = number
  default     = 20
  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be >= 20 GB."
  }
}

variable "max_allocated_storage" {
  description = "Upper bound for storage autoscaling (GB). Set to 0 to disable autoscaling. Recommend at least 2x allocated_storage in prod so the autoscaler has headroom."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type. gp3 is the modern default (cheaper + better IOPS curve than gp2)."
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "standard"], var.storage_type)
    error_message = "storage_type must be one of: gp2, gp3, io1, io2, standard."
  }
}

variable "iops" {
  description = "Provisioned IOPS. Only meaningful for io1/io2/gp3 (when gp3 is above baseline). 0 lets AWS pick the gp3 baseline."
  type        = number
  default     = 0
}

variable "storage_throughput" {
  description = "Storage throughput (MiB/s). Only meaningful for gp3. 0 = AWS default."
  type        = number
  default     = 0
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt storage. Required — no plaintext RDS in fintech. Typically the output of devotica-labs/terraform-aws-kms."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN."
  }
}

# ---------------------------------------------------------------------------
# Master credentials — modern AWS-managed path by default.
# ---------------------------------------------------------------------------

variable "username" {
  description = "Master DB username. Cannot be changed after creation."
  type        = string
  default     = "dbadmin"
}

variable "manage_master_user_password" {
  description = "Let AWS RDS create and manage the master password in AWS Secrets Manager (with automatic rotation). Strongly recommended. When false, you must pass master_password."
  type        = bool
  default     = true
}

variable "master_user_secret_kms_key_arn" {
  description = "KMS key ARN that AWS Secrets Manager uses to encrypt the AWS-managed master password secret. Defaults to var.kms_key_arn (same workload key)."
  type        = string
  default     = ""
}

variable "master_password" {
  description = "Master password. Only used when manage_master_user_password = false. Pass via a sensitive variable; never commit. Empty string when AWS-managed (default)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "iam_database_authentication_enabled" {
  description = "Allow IAM principals to log in via temporary auth tokens (passwordless). On by default — pairs well with terraform-aws-iam roles + per-environment access."
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Name of the initial database to create. Empty string skips the create-database step."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# Networking — caller is responsible for VPC / subnet group / SG.
# ---------------------------------------------------------------------------

variable "db_subnet_group_name" {
  description = "Name of an existing DB subnet group (caller-supplied). The subnet group's subnets must be in at least two AZs."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs attached to the DB instance. Caller is responsible for the SG ingress / egress rules (typically: TCP from app SGs only)."
  type        = list(string)
}

variable "port" {
  description = "Port the DB listens on. Defaults to the engine default (Postgres 5432, MySQL/MariaDB 3306)."
  type        = number
  default     = 0
  validation {
    condition     = var.port == 0 || (var.port >= 1150 && var.port <= 65535)
    error_message = "port must be 0 (engine default) or 1150-65535."
  }
}

variable "publicly_accessible" {
  description = "Whether the DB is reachable on a public IP. NEVER true in fintech prod — should always be false. Validation refuses true."
  type        = bool
  default     = false
  validation {
    condition     = var.publicly_accessible == false
    error_message = "publicly_accessible = true is refused by this module — RDS in fintech must be VPC-internal only."
  }
}

# ---------------------------------------------------------------------------
# HA / Backups / Retention
# ---------------------------------------------------------------------------

variable "multi_az" {
  description = "Enable Multi-AZ deployment (synchronous standby in a second AZ). True by default — production cost, but losing a primary mid-transaction without failover is the worst-case scenario in fintech."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. RBI / SEBI mandate at least 7; many fintechs go to 35 (the AWS max) for transaction-audit needs."
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 7 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be 7-35 (RBI / SEBI minimum, AWS maximum)."
  }
}

variable "backup_window" {
  description = "Preferred UTC backup window (hh24:mi-hh24:mi). Pick a low-traffic window. Default is 18:00-19:00 UTC (23:30-00:30 IST)."
  type        = string
  default     = "18:00-19:00"
}

variable "copy_tags_to_snapshot" {
  description = "Whether automated backups inherit instance tags. Recommended — the tag set is how cost allocation + DR runbooks identify backups."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block `terraform destroy` and AWS-console delete on this instance. True by default for fintech (the cost of accidental deletion >>> the friction of toggling this off before a planned teardown)."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot when this instance is destroyed. Default false — fintech wants a snapshot in case the deletion was a mistake."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier_prefix" {
  description = "Prefix for the final snapshot name. The actual snapshot will be `<prefix>-<identifier>-<timestamp>`. Ignored when skip_final_snapshot = true."
  type        = string
  default     = "final"
}

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------

variable "maintenance_window" {
  description = "Preferred UTC weekly maintenance window (ddd:hh24:mi-ddd:hh24:mi). Pick a window distinct from backup_window. Default Sunday 19:00-20:00 UTC."
  type        = string
  default     = "sun:19:00-sun:20:00"
}

variable "auto_minor_version_upgrade" {
  description = "Apply minor-version engine upgrades automatically during maintenance windows. True by default — minor versions are backwards-compatible and contain CVE fixes."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply pending modifications immediately instead of during the next maintenance window. False by default — apply-immediately causes downtime."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "monitoring_interval" {
  description = "Enhanced Monitoring polling interval in seconds (0, 1, 5, 10, 15, 30, 60). 0 disables. 60 is a sensible prod default."
  type        = number
  default     = 0
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be one of 0, 1, 5, 10, 15, 30, 60."
  }
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights. True by default — free tier covers 7-day retention; longer retention costs more."
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days. 7 is free; 731 (~2 years) is the long-term option for audit."
  type        = number
  default     = 7
  validation {
    condition     = contains([7, 31, 62, 93, 124, 155, 186, 217, 248, 279, 310, 341, 372, 403, 434, 465, 496, 527, 558, 589, 620, 651, 682, 713, 731], var.performance_insights_retention_period)
    error_message = "performance_insights_retention_period must be 7 or a valid month-multiple up to 731."
  }
}

variable "performance_insights_kms_key_arn" {
  description = "KMS key for Performance Insights data. Defaults to var.kms_key_arn (same workload key)."
  type        = string
  default     = ""
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs. Per engine: postgres → [\"postgresql\", \"upgrade\"]; mysql → [\"audit\", \"error\", \"general\", \"slowquery\"]."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Parameter group
# ---------------------------------------------------------------------------

variable "parameter_group_family" {
  description = "DB parameter group family (e.g. \"postgres16\", \"mysql8.0\"). Leave empty to skip the custom parameter group and use the AWS default."
  type        = string
  default     = ""
}

variable "parameters" {
  description = "Custom DB parameters as a list of {name, value, apply_method} objects. Ignored when parameter_group_family is empty."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every taggable resource."
  type        = map(string)
  default     = {}
}
