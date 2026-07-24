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

variable "service_accounts" {
  type        = list(string)
  description = "Explicit service account names the role trusts (each becomes a StringEquals sub condition). Avoid '*' — enumerate the accounts. A '*' anywhere switches the whole condition to StringLike."
  validation {
    condition     = length(var.service_accounts) > 0
    error_message = "service_accounts must list at least one service account (wildcard-only trust is not allowed)."
  }
}

variable "policy_json" {
  type        = string
  description = "Inline least-privilege policy document (JSON) attached to the role."
}
