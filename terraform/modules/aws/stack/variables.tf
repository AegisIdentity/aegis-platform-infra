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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR — unique per environment (no overlap across envs/clouds)."
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "CIDRs allowed to reach a public EKS endpoint (cost profile only — hardened is private)."
}

variable "workload_namespace" {
  type        = string
  default     = "aegis"
  description = "Kubernetes namespace the platform workloads run in (IRSA trust is scoped to it)."
}

variable "services" {
  type        = list(string)
  description = "Service names that get an ECR repository (includes the nginx-served frontend)."
  default = [
    "authorization-server", "identity-service", "tenant-service", "edge-gateway",
    "mfa-webauthn-service", "saml-idp-service", "social-broker-service",
    "scim-provisioning-service", "admin-api-service",
    "admin-console",
  ]
}
