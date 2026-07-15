resource "aws_security_group" "this" {
  name        = "${var.name}-kafka"
  vpc_id      = var.vpc_id
  description = "Kafka brokers — ingress only from the EKS node security group"

  ingress {
    description     = "Kafka TLS from cluster workloads"
    from_port       = 9094
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }

  ingress {
    description     = "Kafka SASL/IAM from cluster workloads"
    from_port       = 9098
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.source_security_group_id]
  }
}

# Topics are provisioned deliberately, never auto-created; replication is
# sized to the broker count so a single broker loss never loses events.
resource "aws_msk_configuration" "this" {
  name           = "${var.name}-events"
  kafka_versions = [var.kafka_version]

  server_properties = <<-PROPERTIES
    auto.create.topics.enable=false
    default.replication.factor=${var.broker_count >= 3 ? 3 : 2}
    min.insync.replicas=${var.broker_count >= 3 ? 2 : 1}
  PROPERTIES
}

resource "aws_cloudwatch_log_group" "broker" {
  count             = var.enable_broker_logs ? 1 : 0
  name              = "/aegis/${var.name}/msk-broker"
  retention_in_days = var.log_retention_days
}

resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.name}-events"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  broker_node_group_info {
    instance_type = var.instance_type
    # Broker count must be a multiple of the subnet count.
    client_subnets  = slice(var.private_subnets, 0, min(var.broker_count, length(var.private_subnets)))
    security_groups = [aws_security_group.this.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.broker_volume_gb
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  # In-transit TLS everywhere; hardened profile additionally requires SASL/IAM
  # so every producer/consumer is an authenticated IAM principal.
  encryption_info {
    encryption_at_rest_kms_key_arn = var.kms_key_arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  client_authentication {
    unauthenticated = !var.iam_authentication
    dynamic "sasl" {
      for_each = var.iam_authentication ? [1] : []
      content {
        iam = true
      }
    }
  }

  dynamic "logging_info" {
    for_each = var.enable_broker_logs ? [1] : []
    content {
      broker_logs {
        cloudwatch_logs {
          enabled   = true
          log_group = aws_cloudwatch_log_group.broker[0].name
        }
      }
    }
  }
}
