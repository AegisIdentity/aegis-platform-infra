variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev/staging/prod)."
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "EKS Kubernetes version."
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m6i.large"]
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "db_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "services" {
  type        = list(string)
  description = "Service names that get an ECR repository."
  default = [
    "authorization-server", "identity-service", "tenant-service", "edge-gateway",
    "mfa-webauthn-service", "saml-idp-service", "social-broker-service",
    "scim-provisioning-service", "admin-api-service",
  ]
}
