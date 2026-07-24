variable "name" {
  type        = string
  description = "Resource name prefix (aegis-<environment>)."
}

variable "environment" {
  type        = string
  description = "Environment name (dev/test/stage/prod)."
}

variable "log_retention_days" {
  type        = number
  default     = 365
  description = "Retention for the audit log bucket's noncurrent versions / expiry."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Optional CMK for CloudTrail and the audit S3 bucket. Null uses SSE-S3 (AES256)."
}

variable "is_organization_trail" {
  type        = bool
  default     = false
  description = "Make CloudTrail an organization trail. Requires running from the Organizations management (or delegated-admin) account — leave false unless that prerequisite is met."
}

variable "guardduty_finding_frequency" {
  type    = string
  default = "FIFTEEN_MINUTES"
}
