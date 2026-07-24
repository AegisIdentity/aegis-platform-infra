variable "name" {
  type        = string
  description = "Resource name prefix (aegis-<environment>)."
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  type        = number
  default     = 365
  description = "Log Analytics workspace retention."
}

variable "aks_id" {
  type        = string
  description = "AKS cluster resource ID (diagnostic settings target)."
}

variable "key_vault_id" {
  type        = string
  description = "Key Vault resource ID — audit logging here is critical: this vault holds the tenant signing keys."
}

variable "acr_id" {
  type        = string
  description = "Container registry resource ID (diagnostic settings target)."
}

variable "postgres_server_id" {
  type        = string
  description = "Postgres Flexible Server resource ID (diagnostic settings target)."
}

variable "defender_plans" {
  type        = list(string)
  description = "Microsoft Defender for Cloud plans to enable (Standard tier)."
  default = [
    "Containers",                    # AKS + ACR
    "KeyVaults",                     # tenant signing-key vault
    "OpenSourceRelationalDatabases", # Postgres Flexible Server
  ]
}
