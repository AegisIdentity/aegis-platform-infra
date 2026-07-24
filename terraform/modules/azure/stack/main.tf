locals {
  name = "aegis-${var.environment}"

  # Two deployment profiles:
  #   cost-optimized — dev/test: free control plane, burstable SKUs, single
  #     zone, no private endpoints, short retention. TLS-only data planes and
  #     RBAC-only access are NOT relaxed — only capacity and redundancy are.
  #   hardened — stage/prod (identical by construction): private AKS API,
  #     zone-redundant everything, private endpoints for every data plane,
  #     public network access disabled, purge protection, long retention.
  profiles = {
    cost-optimized = {
      aks_sku_tier          = "Free"
      aks_private           = false
      aks_zones             = null
      aks_policy            = false
      system_node_count     = 1
      system_vm_size        = "Standard_D2s_v5"
      dedicated_system_pool = false
      user_vm_size          = "Standard_D2s_v5"
      user_min              = 1
      user_max              = 3
      pg_sku                = "B_Standard_B2ms"
      pg_storage_mb         = 32768
      pg_ha                 = false
      pg_geo_backup         = false
      pg_backup_days        = 7
      redis_family          = "C"
      redis_sku             = "Standard"
      redis_capacity        = 1
      redis_zones           = null
      eh_capacity           = 1
      eh_auto_inflate       = false
      acr_sku               = "Standard"
      acr_zone_redundant    = false
      kv_purge_protection   = false
      kv_default_action     = "Allow"
      private_endpoints     = false
      public_network_access = true
      enable_audit          = false
    }
    hardened = {
      aks_sku_tier          = "Standard"
      aks_private           = true
      aks_zones             = ["1", "2", "3"]
      aks_policy            = true
      system_node_count     = 3
      system_vm_size        = "Standard_D4s_v5"
      dedicated_system_pool = true
      user_vm_size          = "Standard_D4s_v5"
      user_min              = 3
      user_max              = 9
      pg_sku                = "GP_Standard_D4s_v3"
      pg_storage_mb         = 131072
      pg_ha                 = true
      pg_geo_backup         = true
      pg_backup_days        = 35
      redis_family          = "P"
      redis_sku             = "Premium"
      redis_capacity        = 1
      redis_zones           = ["1", "2"]
      eh_capacity           = 2
      eh_auto_inflate       = true
      acr_sku               = "Premium"
      acr_zone_redundant    = true
      kv_purge_protection   = true
      kv_default_action     = "Deny"
      private_endpoints     = true
      public_network_access = false
      enable_audit          = true
    }
  }

  p = local.profiles[var.profile]

  pep_subnet_id = local.p.private_endpoints ? module.network.private_endpoints_subnet_id : null
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name}-rg"
  location = var.location
  tags = {
    platform    = "aegis"
    environment = var.environment
    profile     = var.profile
    managedby   = "terraform"
  }
}

module "network" {
  source = "../network"

  name                     = local.name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  address_space            = var.address_space
  aks_subnet_prefix        = cidrsubnet(var.address_space, 4, 0)
  data_subnet_prefix       = cidrsubnet(var.address_space, 8, 16)
  pep_subnet_prefix        = cidrsubnet(var.address_space, 8, 17)
  enable_private_endpoints = local.p.private_endpoints
}

module "aks" {
  source = "../aks"

  name                   = local.name
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  kubernetes_version     = var.kubernetes_version
  sku_tier               = local.p.aks_sku_tier
  private_cluster        = local.p.aks_private
  azure_policy           = local.p.aks_policy
  admin_group_object_ids = var.admin_group_object_ids
  subnet_id              = module.network.aks_subnet_id
  zones                  = local.p.aks_zones
  system_node_count      = local.p.system_node_count
  system_vm_size         = local.p.system_vm_size
  dedicated_system_pool  = local.p.dedicated_system_pool
  user_vm_size           = local.p.user_vm_size
  user_min_count         = local.p.user_min
  user_max_count         = local.p.user_max
}

# Admin password: injected via TF_VAR_pg_admin_password in pipelines, or
# generated here (lands only in encrypted remote state, never in code).
resource "random_password" "pg" {
  length           = 24
  special          = true
  override_special = "!-_=+"
}

module "postgres" {
  source = "../postgres"

  name                   = local.name
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  sku_name               = local.p.pg_sku
  storage_mb             = local.p.pg_storage_mb
  administrator_password = coalesce(var.pg_admin_password, random_password.pg.result)
  delegated_subnet_id    = module.network.data_subnet_id
  private_dns_zone_id    = module.network.postgres_dns_zone_id
  backup_retention_days  = local.p.pg_backup_days
  geo_redundant_backup   = local.p.pg_geo_backup
  zone_redundant_ha      = local.p.pg_ha
  databases              = var.databases
}

module "redis" {
  source = "../redis"

  name                       = local.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  capacity                   = local.p.redis_capacity
  family                     = local.p.redis_family
  sku_name                   = local.p.redis_sku
  zones                      = local.p.redis_zones
  public_network_access      = local.p.public_network_access
  private_endpoint_subnet_id = local.pep_subnet_id
  private_dns_zone_id        = lookup(module.network.privatelink_dns_zone_ids, "redis", null)
}

module "eventhubs" {
  source = "../eventhubs"

  name                       = local.name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  capacity                   = local.p.eh_capacity
  auto_inflate               = local.p.eh_auto_inflate
  public_network_access      = local.p.public_network_access
  private_endpoint_subnet_id = local.pep_subnet_id
  private_dns_zone_id        = lookup(module.network.privatelink_dns_zone_ids, "servicebus", null)
}

module "acr" {
  source = "../acr"

  name                       = replace("${local.name}acr", "-", "")
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  sku                        = local.p.acr_sku
  public_network_access      = local.p.public_network_access
  zone_redundancy            = local.p.acr_zone_redundant
  private_endpoint_subnet_id = local.pep_subnet_id
  private_dns_zone_id        = lookup(module.network.privatelink_dns_zone_ids, "acr", null)
}

module "keyvault" {
  source = "../keyvault"

  name                       = "${local.name}-kv"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  purge_protection           = local.p.kv_purge_protection
  public_network_access      = local.p.public_network_access
  network_default_action     = local.p.kv_default_action
  private_endpoint_subnet_id = local.pep_subnet_id
  private_dns_zone_id        = lookup(module.network.privatelink_dns_zone_ids, "vault", null)
}

# --- Least-privilege identities ---

# The kubelet may pull images. Nothing else touches ACR from the cluster.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                = module.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_identity_object_id
}

# external-secrets may read secrets from this vault — read-only, secrets only.
module "wi_external_secrets" {
  source = "../workload-identity"

  name                = "${local.name}-external-secrets"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = var.workload_namespace
  service_account     = "external-secrets"

  role_assignments = [
    { scope = module.keyvault.id, role = "Key Vault Secrets User" }
  ]
}

# The authorization server creates and uses per-tenant wrapping keys in this
# vault (envelope encryption of tenant signing keys). Crypto Officer on this
# vault only — it cannot read secrets or manage the vault itself.
module "wi_authorization_server" {
  source = "../workload-identity"

  name                = "${local.name}-authorization-server"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  oidc_issuer_url     = module.aks.oidc_issuer_url
  namespace           = var.workload_namespace
  service_account     = "authorization-server"

  role_assignments = [
    { scope = module.keyvault.id, role = "Key Vault Crypto Officer" }
  ]
}

# Account-level detection & audit (M-infra-4): Log Analytics + diagnostic settings for
# AKS/Key Vault/ACR/Postgres (notably Key Vault audit logging — it holds the tenant signing
# keys) + Microsoft Defender for Cloud plans. Hardened profile only. See modules/azure/audit
# for operator prerequisites (Defender is subscription-scoped — omit if managed centrally).
module "audit" {
  count  = local.p.enable_audit ? 1 : 0
  source = "../audit"

  name                = local.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  retention_in_days   = 365

  aks_id             = module.aks.id
  key_vault_id       = module.keyvault.id
  acr_id             = module.acr.id
  postgres_server_id = module.postgres.server_id
}
