# Standard tier exposes the Kafka protocol endpoint the services use.
resource "azurerm_eventhub_namespace" "this" {
  name                = "${var.name}-events"
  location            = var.location
  resource_group_name = var.resource_group_name

  sku      = "Standard"
  capacity = var.capacity

  auto_inflate_enabled     = var.auto_inflate
  maximum_throughput_units = var.auto_inflate ? var.max_throughput_units : null

  public_network_access_enabled = var.public_network_access
  minimum_tls_version           = "1.2"
}

resource "azurerm_private_endpoint" "this" {
  count               = var.private_endpoint_subnet_id == null ? 0 : 1
  name                = "${var.name}-events-pep"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-events"
    private_connection_resource_id = azurerm_eventhub_namespace.this.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
