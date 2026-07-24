# Account-level detection & audit (M-infra-4). Skeleton wired behind the hardened
# profile: CloudTrail (management-event audit trail, log-file validation), GuardDuty
# (threat detection), and AWS Config (resource configuration recorder). Without this an
# attacker using stolen cloud credentials leaves no trail.
#
# Operator prerequisites before first apply:
#   - Only ONE CloudTrail management trail and ONE Config recorder may exist per account;
#     if the account is part of an AWS Organizations landing zone that already deploys
#     these centrally, do NOT also enable this module — set is_organization_trail per the
#     org design or omit the module and rely on the landing zone.
#   - is_organization_trail = true requires the Organizations management/delegated-admin
#     account. Default false creates an account-local trail.
#   - Consider centralizing to a dedicated log-archive account and adding Security Hub +
#     GuardDuty delegated administration at the org level.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  bucket_name = "${var.name}-audit-${data.aws_caller_identity.current.account_id}"
}

# --- Shared, hardened log bucket for CloudTrail + Config ---
resource "aws_s3_bucket" "audit" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "audit" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit" {
  bucket = aws_s3_bucket.audit.id
  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }
  }
}

# CloudTrail and Config both need to write to this bucket.
data "aws_iam_policy_document" "audit_bucket" {
  statement {
    sid     = "CloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.audit.arn]
  }
  statement {
    sid     = "CloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid     = "ConfigAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [aws_s3_bucket.audit.arn]
  }
  statement {
    sid     = "ConfigWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.audit.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "audit" {
  bucket = aws_s3_bucket.audit.id
  policy = data.aws_iam_policy_document.audit_bucket.json
}

# --- CloudTrail: multi-region management-event trail with log-file validation ---
resource "aws_cloudtrail" "this" {
  name                          = "${var.name}-trail"
  s3_bucket_name                = aws_s3_bucket.audit.id
  is_multi_region_trail         = true
  is_organization_trail         = var.is_organization_trail
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  depends_on = [aws_s3_bucket_policy.audit]
}

# --- GuardDuty: continuous threat detection ---
resource "aws_guardduty_detector" "this" {
  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_frequency
}

# --- AWS Config: records resource configuration for audit/compliance ---
data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name}-config"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  name     = var.name
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = var.name
  s3_bucket_name = aws_s3_bucket.audit.id
  depends_on     = [aws_config_configuration_recorder.this, aws_s3_bucket_policy.audit]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}
