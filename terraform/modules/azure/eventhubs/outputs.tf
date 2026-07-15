output "namespace_name" {
  value = azurerm_eventhub_namespace.this.name
}

output "id" {
  value = azurerm_eventhub_namespace.this.id
}

output "kafka_endpoint" {
  value       = "${azurerm_eventhub_namespace.this.name}.servicebus.windows.net:9093"
  description = "Kafka-protocol bootstrap endpoint."
}
