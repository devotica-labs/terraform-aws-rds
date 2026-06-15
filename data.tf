data "aws_partition" "current" {}

# ---------------------------------------------------------------------------
# Enhanced monitoring assume-role policy — fixed shape, only rendered when
# monitoring_interval > 0.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "enhanced_monitoring_assume" {
  count = local.enhanced_monitoring_on ? 1 : 0

  statement {
    sid     = "AllowRDSEnhancedMonitoringAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}
