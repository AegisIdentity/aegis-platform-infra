resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Hardened profile: no public API server. Reach it via VPN/bastion/peered
  # runner; the cluster is otherwise unreachable from the internet.
  private_cluster_enabled = var.private_cluster

  # Workload Identity gives each pod its own Entra ID identity via OIDC
  # federation — no shared cluster credentials, no secrets in pods.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  azure_policy_enabled = var.azure_policy

  # When admin group ids are supplied, cluster access is Entra ID RBAC only —
  # static local accounts are disabled entirely.
  local_account_disabled = length(var.admin_group_object_ids) > 0

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = length(var.admin_group_object_ids) > 0 ? [1] : []
    content {
      azure_rbac_enabled     = true
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  default_node_pool {
    name                         = "system"
    node_count                   = var.system_node_count
    vm_size                      = var.system_vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = var.zones
    only_critical_addons_enabled = var.dedicated_system_pool
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico" # default-deny NetworkPolicies (ARCHITECTURE.md §8)
  }
}

# Workloads run on a separate autoscaled user pool so the system pool stays
# reserved for cluster components (hardened); cost profile shares one pool.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.dedicated_system_pool ? 1 : 0
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = var.user_vm_size
  vnet_subnet_id        = var.subnet_id
  zones                 = var.zones
  auto_scaling_enabled  = true
  min_count             = var.user_min_count
  max_count             = var.user_max_count
}
