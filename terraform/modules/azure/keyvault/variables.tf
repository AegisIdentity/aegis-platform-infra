variable "name" {
  type        = string
  description = "Globally unique, 3-24 chars, alphanumeric + hyphens."
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "purge_protection" {
  type        = bool
  description = "Irreversible once enabled — true for hardened, false for disposable dev/test vaults."
}

variable "public_network_access" {
  type = bool
}

variable "network_default_action" {
  type        = string
  description = "Allow (cost) or Deny (hardened — private endpoint only)."
  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be Allow or Deny."
  }
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}
