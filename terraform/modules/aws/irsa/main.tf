locals {
  issuer = replace(var.oidc_issuer_url, "https://", "")

  # One sub per trusted service account. StringEquals unless a '*' is present anywhere
  # (then StringLike for the whole set). Enumerating accounts avoids a namespace-wide
  # wildcard trust (M-infra-2).
  service_account_subs = [for sa in var.service_accounts : "system:serviceaccount:${var.namespace}:${sa}"]
  sub_match_type       = anytrue([for sa in var.service_accounts : strcontains(sa, "*")]) ? "StringLike" : "StringEquals"
}

# IAM Roles for Service Accounts: the role is assumable only by the named
# Kubernetes service account via the cluster's OIDC provider. This is how a
# pod gets AWS permissions without node-wide credentials.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = local.sub_match_type
      variable = "${local.issuer}:sub"
      values   = local.service_account_subs
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}
