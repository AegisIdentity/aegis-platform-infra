output "client_id" {
  value       = azurerm_user_assigned_identity.this.client_id
  description = "Annotate the service account with azure.workload.identity/client-id = this."
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}
