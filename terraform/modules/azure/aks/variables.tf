variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "sku_tier" {
  type        = string
  description = "Free (cost profile) or Standard (hardened — uptime SLA)."
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "private_cluster" {
  type = bool
}

variable "azure_policy" {
  type = bool
}

variable "admin_group_object_ids" {
  type        = list(string)
  default     = []
  description = "Entra ID groups given Azure RBAC cluster admin. Non-empty disables local accounts."
}

variable "subnet_id" {
  type = string
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "Availability zones for node pools (hardened)."
}

variable "system_node_count" {
  type = number
}

variable "system_vm_size" {
  type = string
}

variable "dedicated_system_pool" {
  type        = bool
  description = "Taint the system pool for critical addons only and add an autoscaled user pool (hardened)."
}

variable "user_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "user_min_count" {
  type    = number
  default = 3
}

variable "user_max_count" {
  type    = number
  default = 9
}
