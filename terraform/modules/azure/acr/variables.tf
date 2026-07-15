variable "name" {
  type        = string
  description = "Globally unique, alphanumeric only."
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  type        = string
  description = "Standard (cost) or Premium (hardened — required for private link)."
}

variable "public_network_access" {
  type = bool
}

variable "zone_redundancy" {
  type    = bool
  default = false
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}
