output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "postgres_endpoint" {
  value = module.postgres.endpoint
}

output "postgres_master_secret_arn" {
  value = module.postgres.master_user_secret_arn
}

output "redis_primary_endpoint" {
  value = module.redis.primary_endpoint
}

output "redis_auth_secret_arn" {
  value = module.redis.auth_secret_arn
}

output "kafka_bootstrap_brokers_tls" {
  value = module.kafka.bootstrap_brokers_tls
}

output "kafka_bootstrap_brokers_sasl_iam" {
  value = module.kafka.bootstrap_brokers_sasl_iam
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "signing_kms_key_arn" {
  value = module.kms.key_arns["signing"]
}

output "external_secrets_role_arn" {
  value = module.irsa_external_secrets.role_arn
}

output "authorization_server_signing_role_arn" {
  value = module.irsa_signing.role_arn
}

output "events_client_role_arn" {
  value = try(module.irsa_events_client[0].role_arn, null)
}
