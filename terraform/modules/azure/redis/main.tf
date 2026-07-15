resource "azurerm_redis_cache" "this" {
  name                = "${var.name}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name

  capacity = var.capacity
  family   = var.family
  sku_name = var.sku_name
  zones    = var.zones

  # TLS only, always — the non-TLS port never opens in any profile.
  minimum_tls_version  = "1.2"
  non_ssl_port_enabled = false

  public_network_access_enabled = var.public_network_access
}

resource "azurerm_private_endpoint" "this" {
  count               = var.private_endpoint_subnet_id == null ? 0 : 1
  name                = "${var.name}-redis-pep"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-redis"
    private_connection_resource_id = azurerm_redis_cache.this.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
