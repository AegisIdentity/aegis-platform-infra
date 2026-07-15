variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "oidc_issuer_url" {
  type        = string
  description = "The AKS cluster's OIDC issuer URL."
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}

variable "role_assignments" {
  type = list(object({
    scope = string
    role  = string
  }))
  description = "Least-privilege built-in roles granted to this identity, each on an explicit scope."
}
