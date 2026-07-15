output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "data_subnet_id" {
  value = azurerm_subnet.data.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "postgres_dns_zone_id" {
  value = azurerm_private_dns_zone.postgres.id
}

output "postgres_dns_zone_link_id" {
  value       = azurerm_private_dns_zone_virtual_network_link.postgres.id
  description = "Depend on this before creating the Flexible Server."
}

output "privatelink_dns_zone_ids" {
  value       = { for k, z in azurerm_private_dns_zone.privatelink : k => z.id }
  description = "vault / redis / acr / servicebus zone ids (empty unless private endpoints enabled)."
}
