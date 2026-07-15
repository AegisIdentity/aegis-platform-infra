variable "name" {
  type        = string
  description = "Cluster name (aegis-<environment>)."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version."
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "endpoint_public_access" {
  type        = bool
  description = "Expose the API server publicly (cost profile only)."
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach a public API endpoint. Narrow this to your office/VPN egress."
}

variable "enabled_log_types" {
  type        = list(string)
  description = "Control-plane log types shipped to CloudWatch."
}

variable "log_retention_days" {
  type = number
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_capacity_type" {
  type        = string
  description = "SPOT (cost profile) or ON_DEMAND (hardened)."
  validation {
    condition     = contains(["SPOT", "ON_DEMAND"], var.node_capacity_type)
    error_message = "node_capacity_type must be SPOT or ON_DEMAND."
  }
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}
