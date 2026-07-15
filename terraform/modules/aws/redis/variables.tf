variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "source_security_group_id" {
  type        = string
  description = "The only security group allowed to reach Redis (EKS nodes)."
}

variable "node_type" {
  type = string
}

variable "num_cache_clusters" {
  type = number
}

variable "automatic_failover" {
  type = bool
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for at-rest encryption (hardened); null uses the AWS-managed key."
}

variable "snapshot_retention_days" {
  type    = number
  default = 1
}

variable "secret_recovery_window_days" {
  type        = number
  default     = 30
  description = "0 allows immediate secret deletion (dev/test teardown); 30 for hardened."
}
