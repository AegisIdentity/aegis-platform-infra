output "resource_group_name" {
  value = module.platform.resource_group_name
}

output "aks_name" {
  value = module.platform.aks_name
}

output "aks_oidc_issuer_url" {
  value = module.platform.aks_oidc_issuer_url
}

output "postgres_fqdn" {
  value = module.platform.postgres_fqdn
}

output "postgres_admin_password" {
  value     = module.platform.postgres_admin_password
  sensitive = true
}

output "redis_hostname" {
  value = module.platform.redis_hostname
}

output "eventhub_kafka_endpoint" {
  value = module.platform.eventhub_kafka_endpoint
}

output "acr_login_server" {
  value = module.platform.acr_login_server
}

output "key_vault_uri" {
  value = module.platform.key_vault_uri
}

output "external_secrets_client_id" {
  value = module.platform.external_secrets_client_id
}

output "authorization_server_client_id" {
  value = module.platform.authorization_server_client_id
}
