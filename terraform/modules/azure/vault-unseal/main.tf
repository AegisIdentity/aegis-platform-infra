# Auto-unseal for the Aegis Vault cluster on AKS (ADR-0015 / ADR-0016).
#
# Azure counterpart of terraform/modules/aws/vault-unseal. Same shape deliberately: one unseal key,
# one snapshot store, one workload identity scoped to the Vault service account. Under ADR-0015 this
# is the entire remaining role of cloud key management — it is not on the token path.

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = ">= 3.100" }
  }
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix, e.g. aegis-prod."
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "aks_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL of the AKS cluster, for workload identity federation."
}

variable "namespace" {
  type    = string
  default = "aegis"
}

variable "service_account" {
  type    = string
  default = "vault"
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "unseal" {
  name                       = "${var.name_prefix}-vault-unseal"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  soft_delete_retention_days = 30
  # Purge protection is REQUIRED, not defensive: purging the unseal key makes an existing Vault
  # cluster permanently unrecoverable, and with it every tenant signing key.
  tags = var.tags
}

resource "azurerm_key_vault_key" "unseal" {
  name         = "vault-unseal"
  key_vault_id = azurerm_key_vault.unseal.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["unwrapKey", "wrapKey"]
}

resource "azurerm_user_assigned_identity" "vault" {
  name                = "${var.name_prefix}-vault-unseal"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Federated to the single Vault service account, not the whole namespace.
resource "azurerm_federated_identity_credential" "vault" {
  name                = "${var.name_prefix}-vault-unseal"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.vault.id
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account}"
}

# Wrap/unwrap only — Vault does not manage the key's lifecycle.
resource "azurerm_key_vault_access_policy" "vault" {
  key_vault_id    = azurerm_key_vault.unseal.id
  tenant_id       = data.azurerm_client_config.current.tenant_id
  object_id       = azurerm_user_assigned_identity.vault.principal_id
  key_permissions = ["Get", "WrapKey", "UnwrapKey"]
}

output "key_vault_name" {
  value = azurerm_key_vault.unseal.name
}

output "unseal_key_name" {
  value = azurerm_key_vault_key.unseal.name
}

output "managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.vault.client_id
  description = "Feed into server.serviceAccount.annotations in the Helm values."
}
