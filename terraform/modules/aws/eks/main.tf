module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.name
  cluster_version = var.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnets
  control_plane_subnet_ids = var.private_subnets

  # IRSA gives each workload its own IAM role scoped to its Kubernetes service
  # account — no shared node credentials, no static keys in pods.
  enable_irsa = true

  # Hardened profile runs the API server private-only; reach it via VPN/bastion
  # or a CI runner inside the VPC. Cost profile keeps a public endpoint but can
  # be narrowed with cluster_endpoint_public_access_cidrs.
  cluster_endpoint_public_access       = var.endpoint_public_access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  # The identity that runs terraform apply administers the cluster; grant any
  # further humans/pipelines access with explicit EKS access entries, not
  # long-lived kubeconfig credentials.
  # L-infra-5: acceptable for bootstrap, but for prod prefer a dedicated, rarely-assumed
  # break-glass role as the cluster creator/admin (rather than a routine CI/human
  # principal), and grant day-to-day access via scoped EKS access entries. Set this false
  # once such a role + access entries are in place so cluster-admin isn't tied to whoever
  # first ran apply.
  enable_cluster_creator_admin_permissions = true

  # Control-plane audit trail. The module encrypts Kubernetes secrets with a
  # dedicated KMS key by default (cluster_encryption_config).
  cluster_enabled_log_types              = var.enabled_log_types
  cloudwatch_log_group_retention_in_days = var.log_retention_days

  # M-infra-3: enable NetworkPolicy enforcement on the VPC CNI so the Helm
  # chart's default-deny egress policy is actually enforced on EKS (the AWS VPC
  # CNI ships with policy enforcement OFF, which would leave the policy inert —
  # Azure AKS enforces via Calico). coredns/kube-proxy pinned as managed addons
  # so the data plane is reconciled by EKS rather than drifting.
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
  }

  eks_managed_node_group_defaults = {
    # IMDSv2 only — blocks SSRF-based credential theft from pods.
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 1
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }
}
