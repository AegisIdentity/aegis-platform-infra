locals {
  name = "aegis-${var.environment}"

  # Two deployment profiles:
  #   cost-optimized — dev/test: single NAT, spot nodes, burstable instances,
  #     single-AZ data tier, short retention. Encryption and least-privilege
  #     network rules are NOT relaxed — only capacity and redundancy are.
  #   hardened — stage/prod (identical by construction): private API endpoint,
  #     CMKs everywhere, multi-AZ data tier, IAM-authenticated Kafka, full
  #     audit logging, long retention, deletion protection.
  profiles = {
    cost-optimized = {
      single_nat_gateway     = true
      enable_flow_logs       = false
      log_retention_days     = 30
      eks_endpoint_public    = true
      eks_log_types          = ["api", "audit"]
      node_instance_types    = ["t3.large"]
      node_capacity_type     = "SPOT"
      node_min               = 1
      node_desired           = 2
      node_max               = 4
      use_cmk                = false
      kms_deletion_window    = 7
      db_instance_class      = "db.t4g.medium"
      db_storage_gb          = 50
      db_multi_az            = false
      db_backup_days         = 7
      db_deletion_protection = false
      db_iam_auth            = false
      db_perf_insights       = false
      redis_node_type        = "cache.t4g.small"
      redis_clusters         = 1
      redis_failover         = false
      redis_snapshot_days    = 1
      secret_recovery_days   = 0
      kafka_instance         = "kafka.t3.small"
      kafka_brokers          = 2
      kafka_volume_gb        = 50
      kafka_iam_auth         = false
      kafka_broker_logs      = false
      enable_audit           = false
    }
    hardened = {
      single_nat_gateway     = false
      enable_flow_logs       = true
      log_retention_days     = 365
      eks_endpoint_public    = false
      eks_log_types          = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      node_instance_types    = ["m6i.large"]
      node_capacity_type     = "ON_DEMAND"
      node_min               = 3
      node_desired           = 3
      node_max               = 9
      use_cmk                = true
      kms_deletion_window    = 30
      db_instance_class      = "db.r6g.large"
      db_storage_gb          = 100
      db_multi_az            = true
      db_backup_days         = 30
      db_deletion_protection = true
      db_iam_auth            = true
      db_perf_insights       = true
      redis_node_type        = "cache.r6g.large"
      redis_clusters         = 2
      redis_failover         = true
      redis_snapshot_days    = 7
      secret_recovery_days   = 30
      kafka_instance         = "kafka.m5.large"
      kafka_brokers          = 3
      kafka_volume_gb        = 200
      kafka_iam_auth         = true
      kafka_broker_logs      = true
      enable_audit           = true
    }
  }

  p = local.profiles[var.profile]
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

module "network" {
  source = "../network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  single_nat_gateway = local.p.single_nat_gateway
  enable_flow_logs   = local.p.enable_flow_logs
  log_retention_days = local.p.log_retention_days
}

module "kms" {
  source = "../kms"

  name                    = local.name
  deletion_window_in_days = local.p.kms_deletion_window

  # The signing key always exists: the authorization server wraps per-tenant
  # token-signing keys with it (envelope encryption). Data-store CMKs are a
  # hardened-profile addition; cost profile uses AWS-managed keys.
  keys = merge(
    { signing = "Aegis per-tenant token signing key wrapping (envelope encryption)" },
    local.p.use_cmk ? {
      rds   = "Aegis RDS storage encryption"
      redis = "Aegis ElastiCache at-rest encryption"
      msk   = "Aegis MSK at-rest encryption"
      ecr   = "Aegis ECR image encryption"
    } : {}
  )
}

module "eks" {
  source = "../eks"

  name                   = local.name
  cluster_version        = var.cluster_version
  vpc_id                 = module.network.vpc_id
  private_subnets        = module.network.private_subnets
  endpoint_public_access = local.p.eks_endpoint_public
  # M-infra-1: cost profile is public — forward the required office/VPN allowlist (the
  # variable's validation guarantees it is non-empty and not 0.0.0.0/0). Hardened is
  # private, so the CIDR list is ignored by AWS; pass 0.0.0.0/0 only to satisfy the API's
  # "publicAccessCidrs must be non-empty" rule (it has no effect while public access is off).
  endpoint_public_access_cidrs = local.p.eks_endpoint_public ? var.endpoint_public_access_cidrs : ["0.0.0.0/0"]
  enabled_log_types            = local.p.eks_log_types
  log_retention_days           = local.p.log_retention_days
  node_instance_types          = local.p.node_instance_types
  node_capacity_type           = local.p.node_capacity_type
  node_min_size                = local.p.node_min
  node_desired_size            = local.p.node_desired
  node_max_size                = local.p.node_max
}

module "postgres" {
  source = "../postgres"

  name                     = local.name
  vpc_id                   = module.network.vpc_id
  private_subnets          = module.network.private_subnets
  source_security_group_id = module.eks.node_security_group_id
  instance_class           = local.p.db_instance_class
  allocated_storage        = local.p.db_storage_gb
  kms_key_arn              = lookup(module.kms.key_arns, "rds", null)
  multi_az                 = local.p.db_multi_az
  backup_retention_days    = local.p.db_backup_days
  deletion_protection      = local.p.db_deletion_protection
  iam_authentication       = local.p.db_iam_auth
  performance_insights     = local.p.db_perf_insights
}

module "redis" {
  source = "../redis"

  name                        = local.name
  environment                 = var.environment
  vpc_id                      = module.network.vpc_id
  private_subnets             = module.network.private_subnets
  source_security_group_id    = module.eks.node_security_group_id
  node_type                   = local.p.redis_node_type
  num_cache_clusters          = local.p.redis_clusters
  automatic_failover          = local.p.redis_failover
  kms_key_arn                 = lookup(module.kms.key_arns, "redis", null)
  snapshot_retention_days     = local.p.redis_snapshot_days
  secret_recovery_window_days = local.p.secret_recovery_days
}

module "kafka" {
  source = "../kafka"

  name                     = local.name
  vpc_id                   = module.network.vpc_id
  private_subnets          = module.network.private_subnets
  source_security_group_id = module.eks.node_security_group_id
  instance_type            = local.p.kafka_instance
  broker_count             = local.p.kafka_brokers
  broker_volume_gb         = local.p.kafka_volume_gb
  kms_key_arn              = lookup(module.kms.key_arns, "msk", null)
  iam_authentication       = local.p.kafka_iam_auth
  enable_broker_logs       = local.p.kafka_broker_logs
  log_retention_days       = local.p.log_retention_days
}

module "ecr" {
  source = "../ecr"

  repositories = var.services
  kms_key_arn  = lookup(module.kms.key_arns, "ecr", null)
}

# --- Least-privilege workload identities (IRSA) ---

# external-secrets may read ONLY this environment's aegis/* secrets — nothing
# else in Secrets Manager, no writes.
module "irsa_external_secrets" {
  source = "../irsa"

  role_name         = "${local.name}-external-secrets"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  namespace         = var.workload_namespace
  service_accounts  = ["external-secrets"]

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAegisEnvSecrets"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecretVersionIds"]
      Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:aegis/${var.environment}/*"
    }]
  })
}

# Only the authorization server can use the signing CMK, and only for the
# envelope operations it needs — it cannot administer or delete the key.
module "irsa_signing" {
  source = "../irsa"

  role_name         = "${local.name}-authorization-server-signing"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  namespace         = var.workload_namespace
  service_accounts  = ["authorization-server"]

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "UseSigningKey"
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext", "kms:DescribeKey"]
      Resource = module.kms.key_arns["signing"]
    }]
  })
}

# Hardened profile runs MSK with SASL/IAM. M-infra-2: trust only the enumerated
# event-producing/consuming service accounts — NOT every SA in the namespace (a
# wildcard let a compromised admin-console nginx pod assume this role and read/write
# all topics). Narrow var.event_client_service_accounts to the real producers/consumers,
# or split per-service roles with topic-prefix-scoped policies for full least privilege.
module "irsa_events_client" {
  count  = local.p.kafka_iam_auth ? 1 : 0
  source = "../irsa"

  role_name         = "${local.name}-events-client"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.cluster_oidc_issuer_url
  namespace         = var.workload_namespace
  service_accounts  = var.event_client_service_accounts

  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConnectToCluster"
        Effect   = "Allow"
        Action   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster"]
        Resource = module.kafka.cluster_arn
      },
      {
        Sid    = "UseAegisTopics"
        Effect = "Allow"
        Action = [
          "kafka-cluster:DescribeTopic", "kafka-cluster:ReadData", "kafka-cluster:WriteData",
          "kafka-cluster:DescribeGroup", "kafka-cluster:AlterGroup"
        ]
        Resource = [
          "${replace(module.kafka.cluster_arn, ":cluster/", ":topic/")}/*",
          "${replace(module.kafka.cluster_arn, ":cluster/", ":group/")}/*"
        ]
      }
    ]
  })
}

# Account-level detection & audit (M-infra-4): CloudTrail + GuardDuty + AWS Config.
# Hardened profile only — dev/test rely on the same controls at the org/landing-zone level
# (or accept the gap by design). See modules/aws/audit for operator prerequisites (single
# trail/recorder per account, org-trail requires the management account).
module "audit" {
  count  = local.p.enable_audit ? 1 : 0
  source = "../audit"

  name               = local.name
  environment        = var.environment
  log_retention_days = local.p.log_retention_days
}
