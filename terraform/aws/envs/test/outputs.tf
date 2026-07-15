output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_endpoint" {
  value = module.platform.cluster_endpoint
}

output "postgres_endpoint" {
  value = module.platform.postgres_endpoint
}

output "postgres_master_secret_arn" {
  value = module.platform.postgres_master_secret_arn
}

output "redis_primary_endpoint" {
  value = module.platform.redis_primary_endpoint
}

output "redis_auth_secret_arn" {
  value = module.platform.redis_auth_secret_arn
}

output "kafka_bootstrap_brokers_tls" {
  value = module.platform.kafka_bootstrap_brokers_tls
}

output "kafka_bootstrap_brokers_sasl_iam" {
  value = module.platform.kafka_bootstrap_brokers_sasl_iam
}

output "ecr_repository_urls" {
  value = module.platform.ecr_repository_urls
}

output "signing_kms_key_arn" {
  value = module.platform.signing_kms_key_arn
}

output "external_secrets_role_arn" {
  value = module.platform.external_secrets_role_arn
}

output "authorization_server_signing_role_arn" {
  value = module.platform.authorization_server_signing_role_arn
}

output "events_client_role_arn" {
  value = module.platform.events_client_role_arn
}
