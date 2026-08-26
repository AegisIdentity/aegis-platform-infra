# Auto-unseal for the Aegis Vault cluster (ADR-0015 / ADR-0016).
#
# This module provisions ONLY what Vault needs to unseal itself, plus the snapshot bucket. Under
# ADR-0015 that is the entire remaining role of cloud KMS: it is no longer an application dependency
# on the token path, so a KMS outage after unseal does not stop token signing.

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix, e.g. aegis-prod."
}

variable "eks_oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN of the EKS cluster, for IRSA."
}

variable "eks_oidc_provider_url" {
  type        = string
  description = "OIDC provider URL (no https:// scheme)."
}

variable "namespace" {
  type        = string
  default     = "aegis"
  description = "Kubernetes namespace Vault runs in."
}

variable "service_account" {
  type        = string
  default     = "vault"
  description = "Kubernetes service account Vault runs as."
}

variable "tags" {
  type    = map(string)
  default = {}
}

# The unseal key. Rotation is enabled: this key never encrypts application data directly, only
# Vault's own root key, so rotating it is cheap and uneventful.
resource "aws_kms_key" "unseal" {
  description             = "${var.name_prefix} Vault auto-unseal"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "unseal" {
  name          = "alias/${var.name_prefix}-vault-unseal"
  target_key_id = aws_kms_key.unseal.key_id
}

# Raft snapshots. Losing the Raft log means losing every tenant signing key — by design those keys
# exist nowhere else — so this bucket is versioned, encrypted and locked down.
resource "aws_s3_bucket" "snapshots" {
  bucket = "${var.name_prefix}-vault-snapshots"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "snapshots" {
  bucket = aws_s3_bucket.snapshots.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.unseal.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "snapshots" {
  bucket                  = aws_s3_bucket.snapshots.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IRSA role for the Vault pods. Scoped to the single service account — not the namespace — so no
# other workload in the namespace can assume it and unseal Vault.
data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.eks_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vault_unseal" {
  name               = "${var.name_prefix}-vault-unseal"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Encrypt/Decrypt/DescribeKey only. Vault does not need to manage the key, and granting kms:* here
# would let a compromised Vault pod schedule deletion of the key that protects its own root key.
data "aws_iam_policy_document" "unseal" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.unseal.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.snapshots.arn, "${aws_s3_bucket.snapshots.arn}/*"]
  }
}

resource "aws_iam_role_policy" "unseal" {
  name   = "${var.name_prefix}-vault-unseal"
  role   = aws_iam_role.vault_unseal.id
  policy = data.aws_iam_policy_document.unseal.json
}

output "kms_key_id" {
  value       = aws_kms_key.unseal.key_id
  description = "Feed into the Helm values seal \"awskms\" stanza."
}

output "role_arn" {
  value       = aws_iam_role.vault_unseal.arn
  description = "Feed into server.serviceAccount.annotations in the Helm values."
}

output "snapshot_bucket" {
  value = aws_s3_bucket.snapshots.bucket
}
