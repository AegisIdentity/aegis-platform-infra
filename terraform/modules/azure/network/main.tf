resource "azurerm_virtual_network" "this" {
  name                = "${var.name}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.address_space]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}

resource "azurerm_subnet" "data" {
  name                 = "data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.data_subnet_prefix]

  delegation {
    name = "pg"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

# Private endpoints for Key Vault, ACR, Redis and Event Hubs land here so the
# data-plane traffic never leaves the VNet (hardened profile).
resource "azurerm_subnet" "private_endpoints" {
  name                              = "private-endpoints"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = [var.pep_subnet_prefix]
  private_endpoint_network_policies = var.enable_private_endpoints ? "Enabled" : "Disabled"
}

# --- East-west least privilege ---
# Postgres lives alone in the delegated data subnet: only 5432 from the AKS
# subnet is allowed in; everything else (including the rest of the VNet) is
# denied. The AKS subnet itself is governed by AKS-managed NIC rules plus
# default-deny Kubernetes NetworkPolicies (Calico).

resource "azurerm_network_security_group" "data" {
  name                = "${var.name}-data-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-postgres-from-aks"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = var.data_subnet_prefix
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.name}-pep-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-data-planes-from-aks"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "5671", "6380", "9093"]
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = var.pep_subnet_prefix
  }

  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  count                     = var.enable_private_endpoints ? 1 : 0
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints[0].id
}

# --- Private DNS ---
# Postgres Flexible Server with VNet integration always needs its zone; the
# privatelink zones exist only when private endpoints are on.

locals {
  privatelink_zones = var.enable_private_endpoints ? {
    vault      = "privatelink.vaultcore.azure.net"
    redis      = "privatelink.redis.cache.windows.net"
    acr        = "privatelink.azurecr.io"
    servicebus = "privatelink.servicebus.windows.net"
  } : {}
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.name}-pg-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.this.id
}

resource "azurerm_private_dns_zone" "privatelink" {
  for_each            = local.privatelink_zones
  name                = each.value
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privatelink" {
  for_each              = local.privatelink_zones
  name                  = "${var.name}-${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink[each.key].name
  virtual_network_id    = azurerm_virtual_network.this.id
}
