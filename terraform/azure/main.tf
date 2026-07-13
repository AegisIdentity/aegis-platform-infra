locals {
  name = "aegis-${var.environment}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
  tags = {
    platform    = "aegis"
    environment = var.environment
    managedby   = "terraform"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.name}-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.61.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.61.0.0/20"]
}

resource "azurerm_subnet" "data" {
  name                 = "data"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.61.16.0/24"]
  delegation {
    name = "pg"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

# --- AKS with Workload Identity (pod-level Azure identity for Key Vault access) ---

resource "azurerm_kubernetes_cluster" "aks" {
  name                      = local.name
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  dns_prefix                = local.name
  kubernetes_version        = var.kubernetes_version
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico" # default-deny NetworkPolicies (ARCHITECTURE.md §8)
  }
}

# --- PostgreSQL Flexible Server (database-per-service) ---

resource "azurerm_postgresql_flexible_server" "pg" {
  name                          = "${local.name}-pg"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "16"
  sku_name                      = var.postgres_sku
  storage_mb                    = 65536
  administrator_login           = "aegis"
  administrator_password        = var.pg_admin_password
  delegated_subnet_id           = azurerm_subnet.data.id
  public_network_access_enabled = false
  zone                          = "1"
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  for_each  = toset(["aegis_authz", "aegis_identity", "aegis_tenant"])
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.pg.id
}

# --- Redis, Event Hubs (Kafka endpoint), ACR, Key Vault ---

resource "azurerm_redis_cache" "redis" {
  name                 = "${local.name}-redis"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  capacity             = 1
  family               = "P"
  sku_name             = "Premium"
  minimum_tls_version  = "1.2"
  non_ssl_port_enabled = false
}

resource "azurerm_eventhub_namespace" "events" {
  name                = "${local.name}-events"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard" # Standard+ exposes the Kafka protocol endpoint
  capacity            = 2
}

resource "azurerm_container_registry" "acr" {
  name                = replace("${local.name}acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_key_vault" "kv" {
  name                       = replace("${local.name}-kv", "_", "-")
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = true
  rbac_authorization_enabled = true
}

data "azurerm_client_config" "current" {}
