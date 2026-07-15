variable "environment" {
  type        = string
  description = "Environment name (dev/test/stage/prod)."
  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be one of dev, test, stage, prod."
  }
}

variable "profile" {
  type        = string
  description = "cost-optimized (dev/test) or hardened (stage/prod)."
  validation {
    condition     = contains(["cost-optimized", "hardened"], var.profile)
    error_message = "profile must be cost-optimized or hardened."
  }
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "address_space" {
  type        = string
  description = "VNet CIDR — unique per environment (no overlap across envs/clouds)."
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "admin_group_object_ids" {
  type        = list(string)
  default     = []
  description = "Entra ID groups given cluster admin via Azure RBAC. Non-empty disables local accounts (recommended for stage/prod)."
}

variable "workload_namespace" {
  type    = string
  default = "aegis"
}

variable "pg_admin_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional override; when null a random password is generated (kept in encrypted state)."
}

variable "databases" {
  type        = list(string)
  description = "One database per service (ADR-0002)."
  default = [
    "aegis_authz", "aegis_identity", "aegis_tenant", "aegis_social",
    "aegis_mfa", "aegis_admin", "aegis_scim",
  ]
}
