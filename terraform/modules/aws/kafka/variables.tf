variable "name" {
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
  description = "The only security group allowed to reach the brokers (EKS nodes)."
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "instance_type" {
  type = string
}

variable "broker_count" {
  type        = number
  description = "Must be a multiple of the AZ/subnet count used (2 for cost, 3 for hardened)."
}

variable "broker_volume_gb" {
  type = number
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for at-rest encryption (hardened); null uses the AWS-managed key."
}

variable "iam_authentication" {
  type        = bool
  description = "Require SASL/IAM (hardened). When false, in-VPC TLS clients inside the SG may connect unauthenticated."
}

variable "enable_broker_logs" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 90
}
