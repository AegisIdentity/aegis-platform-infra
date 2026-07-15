resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.private_subnets
}

resource "aws_security_group" "this" {
  name        = "${var.name}-redis"
  vpc_id      = var.vpc_id
  description = "Redis — ingress only from the EKS node security group"

  ingress {
    description     = "Redis TLS from cluster workloads"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }
}

# AUTH is enforced in addition to TLS and the security group — a compromised
# pod on the network still cannot talk to Redis without the token.
# ElastiCache forbids space, ", / and @ in auth tokens.
resource "random_password" "auth" {
  length           = 48
  special          = true
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "auth" {
  name                    = "aegis/${var.environment}/redis-auth"
  description             = "Redis AUTH token for ${var.name}"
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id     = aws_secretsmanager_secret.auth.id
  secret_string = jsonencode({ auth_token = random_password.auth.result })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Aegis sessions, transient protocol state, rate limiting"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.node_type

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.automatic_failover
  multi_az_enabled           = var.automatic_failover

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result

  snapshot_retention_limit = var.snapshot_retention_days
  subnet_group_name        = aws_elasticache_subnet_group.this.name
  security_group_ids       = [aws_security_group.this.id]
}
