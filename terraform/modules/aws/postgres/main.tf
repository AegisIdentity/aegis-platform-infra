resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-pg"
  subnet_ids = var.private_subnets
}

# Least privilege: only the EKS worker-node security group may open 5432.
# No CIDR-wide ingress, no egress the database does not need.
resource "aws_security_group" "this" {
  name        = "${var.name}-pg"
  vpc_id      = var.vpc_id
  description = "Postgres — ingress only from the EKS node security group"

  ingress {
    description     = "Postgres from cluster workloads"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }
}

# TLS is not optional: rds.force_ssl rejects plaintext connections.
resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_name  = "aegis"
  username = "aegis"
  # Master credential lives in Secrets Manager, rotated by RDS — never in state
  # or tfvars. Per-service databases/roles are created by the migration job.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az                            = var.multi_az
  backup_retention_period             = var.backup_retention_days
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = !var.deletion_protection
  final_snapshot_identifier           = var.deletion_protection ? "${var.name}-pg-final" : null
  copy_tags_to_snapshot               = true
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = var.iam_authentication
  performance_insights_enabled        = var.performance_insights
}
