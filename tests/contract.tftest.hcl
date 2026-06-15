# Contract tests — output surface stays stable across minor + patch versions.

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
  identifier             = "contract-test-db"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t4g.medium"
  kms_key_arn            = "arn:aws:kms:ap-south-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  db_subnet_group_name   = "test-subnet-group"
  vpc_security_group_ids = ["sg-1234567890abcdef0"]
}

run "single_instance_planned" {
  command = plan
  assert {
    condition     = length([aws_db_instance.this]) == 1
    error_message = "Exactly one aws_db_instance.this resource must be planned."
  }
}

run "kms_key_id_wired" {
  command = plan
  assert {
    condition     = aws_db_instance.this.kms_key_id == "arn:aws:kms:ap-south-1:123456789012:key/12345678-1234-1234-1234-123456789012"
    error_message = "kms_key_id must equal var.kms_key_arn (no mutation)."
  }
}

run "engine_passthrough" {
  command = plan
  assert {
    condition     = aws_db_instance.this.engine == "postgres"
    error_message = "engine must equal var.engine."
  }
  assert {
    condition     = aws_db_instance.this.engine_version == "16.4"
    error_message = "engine_version must equal var.engine_version."
  }
}

run "instance_class_passthrough" {
  command = plan
  assert {
    condition     = aws_db_instance.this.instance_class == "db.t4g.medium"
    error_message = "instance_class must equal var.instance_class."
  }
}

run "network_inputs_passthrough" {
  command = plan
  assert {
    condition     = aws_db_instance.this.db_subnet_group_name == "test-subnet-group"
    error_message = "db_subnet_group_name must equal var.db_subnet_group_name."
  }
  assert {
    condition     = length(aws_db_instance.this.vpc_security_group_ids) == 1
    error_message = "vpc_security_group_ids must be wired through."
  }
}

run "backup_retention_in_compliant_range" {
  command = plan
  assert {
    condition     = aws_db_instance.this.backup_retention_period >= 7
    error_message = "Default backup_retention_period must be >= 7 (RBI/SEBI floor)."
  }
}
