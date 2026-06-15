# Changelog

All notable changes to this module are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## 0.1.0 (2026-06-15)


### Features

* initial terraform-aws-rds module ([836756e](https://github.com/devotica-labs/terraform-aws-rds/commit/836756ec75b36cde5cda16ce77e613cfc09b1a99))


### Bug Fixes

* **tflint:** reference var.publicly_accessible in aws_db_instance ([6d04ed4](https://github.com/devotica-labs/terraform-aws-rds/commit/6d04ed4fa9b1ceb86e1d336b71a79a2a55024ff0))

## [Unreleased]

### Added
- Initial module scaffold.
- Single `aws_db_instance` with fintech-safe defaults: storage_encrypted
  forced true with required kms_key_arn, deletion_protection on, multi-AZ
  on, IAM database authentication on, Performance Insights on, backup
  retention floor 7 days, publicly_accessible refused at validation.
- Modern AWS-managed master password via `manage_master_user_password = true`
  (default). RDS provisions the secret in AWS Secrets Manager with automatic
  rotation, encrypted with the workload KMS key by default.
- Engine variable supports `postgres` (default 16.4), `mysql`, `mariadb`.
  Port defaults to the engine-appropriate value (5432 / 3306).
- Custom parameter group (`var.parameter_group_family` + `var.parameters`)
  is opt-in — module skips it when either input is absent and uses the
  AWS default group.
- Enhanced monitoring IAM role (`monitoring.rds.amazonaws.com` assume)
  created only when `monitoring_interval > 0`.
- Final-snapshot identifier carries a random suffix so back-to-back
  destroy/apply cycles don't collide on snapshot names.
- `examples/basic` (single Postgres on t4g.medium with module defaults)
  and `examples/complete` (prod-style: m7g.large, gp3 + IOPS,
  35-day backup retention, custom parameter group with `pg_stat_statements`,
  enhanced monitoring + CloudWatch log exports).
- `tests/unit.tftest.hcl` (15 assertions, mock_provider, plan-only),
  `tests/contract.tftest.hcl` (6 output-surface contracts), and
  `tests/integration.tftest.hcl` (apply + assert + destroy on workflow_dispatch).
