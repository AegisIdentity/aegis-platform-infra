variable "role_name" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the service account."
}

variable "service_account" {
  type        = string
  description = "Service account name; may contain * (matched with StringLike)."
}

variable "policy_json" {
  type        = string
  description = "Inline least-privilege policy document (JSON) attached to the role."
}
