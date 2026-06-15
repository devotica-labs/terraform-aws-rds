# Integration tests — apply + assert + destroy.
# Requires real AWS credentials AND pre-existing networking (subnet group + SG).
# Triggered via workflow_dispatch on integration.yml.
#
# Run manually:
#   terraform test -filter=tests/integration.tftest.hcl \
#     -var=db_subnet_group_name=existing-test-subnet-group \
#     -var=vpc_security_group_ids='["sg-existing"]' \
#     -var=kms_key_arn=arn:aws:kms:...

provider "aws" {
  region = "ap-south-1"
}

variables {
  identifier     = "integ-test-rds"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50

  # Caller must supply these — no defaults that would create infra
  # incidental to this test.
  kms_key_arn            = ""
  db_subnet_group_name   = ""
  vpc_security_group_ids = []

  # Faster destroy for the integration test
  skip_final_snapshot = true

  tags = { Environment = "integration-test", Ephemeral = "true" }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_db_instance.this.arn != ""
    error_message = "DB instance ARN must be set after apply."
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "Storage must be encrypted."
  }
  assert {
    condition     = aws_db_instance.this.iam_database_authentication_enabled == true
    error_message = "IAM database auth must be on."
  }
  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "deletion_protection must be on by default."
  }
}
