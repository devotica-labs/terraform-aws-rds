# Contributing

## Setup

```bash
brew install terraform tflint tfsec gitleaks pre-commit terraform-docs
pre-commit install
```

## Running tests locally

```bash
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl
terraform test -filter=tests/contract.tftest.hcl
```

The integration tests need real AWS creds + a pre-existing subnet group and security group. Run via `workflow_dispatch` on `integration.yml`, or locally:

```bash
terraform test -filter=tests/integration.tftest.hcl \
  -var=kms_key_arn=arn:aws:kms:ap-south-1:111122223333:key/... \
  -var=db_subnet_group_name=test-subnet-group \
  -var='vpc_security_group_ids=["sg-12345"]'
```

## Commit message format

We use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Semver bump |
|---|---|
| `feat:` | minor |
| `fix:`, `docs:`, `chore:` | patch |
| `feat!:` or `BREAKING CHANGE:` footer | major |

## Branch protection

`main` requires all CI checks green + one non-author review.
No direct pushes.
