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
  description = "The only security group allowed to reach Postgres (EKS nodes)."
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type    = number
  default = 50
}

variable "max_allocated_storage" {
  type    = number
  default = 500
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "CMK for storage encryption (hardened); null uses the AWS-managed key."
}

variable "multi_az" {
  type = bool
}

variable "backup_retention_days" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "iam_authentication" {
  type    = bool
  default = false
}

variable "performance_insights" {
  type    = bool
  default = false
}
