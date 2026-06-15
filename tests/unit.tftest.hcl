# Plan-only unit tests — no AWS credentials required.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "random" {}

variables {
  identifier             = "unit-test-db"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t4g.medium"
  kms_key_arn            = "arn:aws:kms:ap-south-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  db_subnet_group_name   = "test-subnet-group"
  vpc_security_group_ids = ["sg-1234567890abcdef0"]
  tags                   = { Environment = "unit-test" }
}

run "instance_planned" {
  command = plan
  assert {
    condition     = aws_db_instance.this.identifier == "unit-test-db"
    error_message = "DB identifier must match var.identifier."
  }
}

run "storage_always_encrypted" {
  command = plan
  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "storage_encrypted must always be true — the module forces it."
  }
  assert {
    condition     = aws_db_instance.this.kms_key_id != ""
    error_message = "kms_key_id must be wired through."
  }
}

run "deletion_protection_default_on" {
  command = plan
  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "deletion_protection must default to true."
  }
}

run "iam_db_auth_default_on" {
  command = plan
  assert {
    condition     = aws_db_instance.this.iam_database_authentication_enabled == true
    error_message = "iam_database_authentication_enabled must default to true."
  }
}

run "multi_az_default_on" {
  command = plan
  assert {
    condition     = aws_db_instance.this.multi_az == true
    error_message = "multi_az must default to true (HA in fintech is non-negotiable)."
  }
}

run "publicly_accessible_always_false" {
  command = plan
  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "publicly_accessible must always be false — the module refuses true."
  }
}

run "managed_master_password_default_on" {
  command = plan
  variables {
    manage_master_user_password = true
  }
  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true
    error_message = "manage_master_user_password must propagate to the resource."
  }
}

run "default_port_postgres" {
  command = plan
  assert {
    condition     = aws_db_instance.this.port == 5432
    error_message = "Postgres engine must default to port 5432."
  }
}

run "default_port_mysql" {
  command = plan
  variables {
    engine         = "mysql"
    engine_version = "8.0.39"
  }
  assert {
    condition     = aws_db_instance.this.port == 3306
    error_message = "MySQL engine must default to port 3306."
  }
}

run "explicit_port_overrides_engine_default" {
  command = plan
  variables {
    port = 6543
  }
  assert {
    condition     = aws_db_instance.this.port == 6543
    error_message = "Explicit var.port must override engine default."
  }
}

run "enhanced_monitoring_role_created_when_interval_gt_0" {
  command = plan
  variables {
    monitoring_interval = 60
  }
  assert {
    condition     = length(aws_iam_role.enhanced_monitoring) == 1
    error_message = "Enhanced monitoring role must be created when monitoring_interval > 0."
  }
}

run "enhanced_monitoring_role_absent_when_interval_0" {
  command = plan
  assert {
    condition     = length(aws_iam_role.enhanced_monitoring) == 0
    error_message = "Enhanced monitoring role must NOT exist when monitoring_interval = 0."
  }
}

run "custom_parameter_group_only_when_family_and_params" {
  command = plan
  assert {
    condition     = length(aws_db_parameter_group.this) == 0
    error_message = "No custom parameter group when both family + params absent."
  }
}

run "custom_parameter_group_created_when_both_present" {
  command = plan
  variables {
    parameter_group_family = "postgres16"
    parameters = [
      { name = "log_connections", value = "1" }
    ]
  }
  assert {
    condition     = length(aws_db_parameter_group.this) == 1
    error_message = "Custom parameter group must be created when family + params both set."
  }
}

run "tags_merged_with_defaults" {
  command = plan
  assert {
    condition     = aws_db_instance.this.tags["ManagedBy"] == "terraform"
    error_message = "Module-default tag ManagedBy must be merged."
  }
  assert {
    condition     = aws_db_instance.this.tags["Module"] == "terraform-aws-rds"
    error_message = "Module-default tag Module must be terraform-aws-rds."
  }
}
