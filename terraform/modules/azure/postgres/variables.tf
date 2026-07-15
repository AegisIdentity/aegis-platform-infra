variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_name" {
  type = string
}

variable "storage_mb" {
  type = number
}

variable "administrator_password" {
  type      = string
  sensitive = true
}

variable "delegated_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
}

variable "backup_retention_days" {
  type = number
}

variable "geo_redundant_backup" {
  type = bool
}

variable "zone_redundant_ha" {
  type = bool
}

variable "databases" {
  type        = list(string)
  description = "One database per service (ADR-0002)."
}
