variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "address_space" {
  type        = string
  description = "VNet CIDR — unique per environment (no overlap across envs/clouds)."
}

variable "aks_subnet_prefix" {
  type = string
}

variable "data_subnet_prefix" {
  type = string
}

variable "pep_subnet_prefix" {
  type = string
}

variable "enable_private_endpoints" {
  type        = bool
  description = "Create the private-endpoints subnet NSG and privatelink DNS zones (hardened profile)."
}
