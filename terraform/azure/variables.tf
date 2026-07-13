variable "location" {
  type    = string
  default = "westeurope"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "postgres_sku" {
  type    = string
  default = "GP_Standard_D2s_v3"
}

variable "pg_admin_password" {
  type        = string
  sensitive   = true
  description = "Postgres admin password (inject via TF_VAR_pg_admin_password / pipeline secret)."
}
