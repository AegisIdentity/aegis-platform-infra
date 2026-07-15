output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_name" {
  value = module.aks.name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "postgres_fqdn" {
  value = module.postgres.fqdn
}

output "postgres_admin_password" {
  value     = coalesce(var.pg_admin_password, random_password.pg.result)
  sensitive = true
}

output "redis_hostname" {
  value = module.redis.hostname
}

output "eventhub_kafka_endpoint" {
  value = module.eventhubs.kafka_endpoint
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

output "external_secrets_client_id" {
  value = module.wi_external_secrets.client_id
}

output "authorization_server_client_id" {
  value = module.wi_authorization_server.client_id
}
