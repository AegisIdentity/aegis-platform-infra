variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "capacity" {
  type = number
}

variable "family" {
  type        = string
  description = "C (Basic/Standard) or P (Premium)."
}

variable "sku_name" {
  type = string
}

variable "zones" {
  type    = list(string)
  default = null
}

variable "public_network_access" {
  type = bool
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}
