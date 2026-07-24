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
  default     = []
  description = "CIDRs allowed to reach the public EKS endpoint (cost profile only — hardened is private). Must be a narrow office/VPN allowlist; 0.0.0.0/0 is rejected."

  # M-infra-1: the cost profile (dev/test) exposes a public API server. It must be
  # restricted to specific office/VPN CIDRs — never left open to the internet. When the
  # endpoint is public (cost profile), require a non-empty, non-0.0.0.0/0 allowlist.
  # Hardened (private endpoint) ignores this, so [] is fine there.
  validation {
    condition = var.profile != "cost-optimized" || (
      length(var.endpoint_public_access_cidrs) > 0 &&
      !contains(var.endpoint_public_access_cidrs, "0.0.0.0/0")
    )
    error_message = "endpoint_public_access_cidrs must be a non-empty office/VPN allowlist (and must not contain 0.0.0.0/0) for the cost-optimized profile, which exposes a public EKS API endpoint."
  }
}

variable "workload_namespace" {
  type        = string
  default     = "aegis"
  description = "Kubernetes namespace the platform workloads run in (IRSA trust is scoped to it)."
}

variable "event_client_service_accounts" {
  type        = list(string)
  description = "M-infra-2: service accounts allowed to assume the MSK events-client IRSA role (SASL/IAM producers/consumers). Explicit allowlist — no namespace wildcard. Narrow to the services that actually use Kafka."
  default = [
    "authorization-server", "identity-service", "tenant-service",
    "social-broker-service", "mfa-webauthn-service", "admin-api-service",
    "scim-provisioning-service",
  ]
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
