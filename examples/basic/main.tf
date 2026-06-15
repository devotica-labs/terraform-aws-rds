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

  identifier     = "my-app-db"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t4g.medium"

  allocated_storage     = 20
  max_allocated_storage = 100

  # KMS key for storage encryption — required. Typically from
  # devotica-labs/terraform-aws-kms.
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/00000000-0000-0000-0000-000000000000"

  # Networking — caller-supplied. Subnet group must span at least two AZs.
  db_subnet_group_name   = "my-vpc-private-db"
  vpc_security_group_ids = ["sg-00000000000000000"]

  db_name = "myapp"

  # Defaults already cover the fintech baseline: multi_az on, 7-day backups,
  # deletion_protection on, IAM auth on, perf insights on, AWS-managed
  # master password.

  tags = {
    Environment = "example"
    Project     = "terraform-aws-rds"
    Owner       = "platform@devotica.com"
    CostCenter  = "PLATFORM-OSS"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/devotica-labs/terraform-aws-rds"
  }
}
