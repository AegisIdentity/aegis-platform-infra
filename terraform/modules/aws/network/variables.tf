variable "name" {
  type        = string
  description = "Name prefix (aegis-<environment>)."
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block."
}

variable "single_nat_gateway" {
  type        = bool
  description = "One NAT gateway (cost-optimized) vs one per AZ (hardened)."
}

variable "enable_flow_logs" {
  type        = bool
  description = "Record VPC flow logs to CloudWatch (hardened profile)."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for flow logs."
}
