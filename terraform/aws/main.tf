locals {
  name = "aegis-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# --- Network + Kubernetes (community modules — the realistic production choice) ---

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod"
  enable_dns_hostnames = true

  # Tags required by the AWS Load Balancer Controller.
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Pod identity via IRSA is enabled so workloads can assume IAM roles (Secrets Manager, KMS).
  enable_irsa                              = true
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 2
      max_size       = 6
      desired_size   = var.node_desired_size
    }
  }
}

# --- PostgreSQL (one instance; database-per-service inside it, or one instance per service) ---

resource "aws_db_subnet_group" "pg" {
  name       = "${local.name}-pg"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "pg" {
  name        = "${local.name}-pg"
  vpc_id      = module.vpc.vpc_id
  description = "Postgres access from the cluster only"
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier                  = "${local.name}-pg"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = var.db_instance_class
  allocated_storage           = 50
  max_allocated_storage       = 500
  storage_encrypted           = true
  db_name                     = "aegis"
  username                    = "aegis"
  manage_master_user_password = true # secret managed in Secrets Manager
  db_subnet_group_name        = aws_db_subnet_group.pg.name
  vpc_security_group_ids      = [aws_security_group.pg.id]
  multi_az                    = var.environment == "prod"
  backup_retention_period     = 14
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
}

# --- Redis (ElastiCache) ---

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name}-redis"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${local.name}-redis"
  description                = "Aegis sessions, transient protocol state, rate limiting"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.r6g.large"
  num_cache_clusters         = var.environment == "prod" ? 2 : 1
  automatic_failover_enabled = var.environment == "prod"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
}

# --- Kafka (MSK) ---

resource "aws_msk_cluster" "events" {
  cluster_name           = "${local.name}-events"
  kafka_version          = "3.6.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.m5.large"
    client_subnets  = module.vpc.private_subnets
    security_groups = [aws_security_group.pg.id]
    storage_info {
      ebs_storage_info {
        volume_size = 100
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
    }
  }
}

# --- Container registry (one repo per service) + KMS-backed secrets ---

resource "aws_ecr_repository" "service" {
  for_each             = toset(var.services)
  name                 = "aegis/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_kms_key" "signing" {
  description             = "Aegis per-tenant token signing key wrapping (envelope encryption)"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}
