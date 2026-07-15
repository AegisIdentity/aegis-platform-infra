resource "azurerm_postgresql_flexible_server" "this" {
  name                = "${var.name}-pg"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "16"

  sku_name   = var.sku_name
  storage_mb = var.storage_mb

  administrator_login    = "aegis"
  administrator_password = var.administrator_password

  # VNet-integrated: the server has no public IP at all. Reachable only from
  # the delegated data subnet (NSG: 5432 from AKS only).
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  zone                         = "1"
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  dynamic "high_availability" {
    for_each = var.zone_redundant_ha ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }
}

# Database-per-service (ADR-0002): each service owns its schema; no service
# ever reads another service's tables.
resource "azurerm_postgresql_flexible_server_database" "db" {
  for_each  = toset(var.databases)
  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
}
