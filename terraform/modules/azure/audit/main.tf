# Account-level detection & audit (M-infra-4). Skeleton wired behind the hardened
# profile: a Log Analytics workspace, diagnostic settings streaming logs from AKS, Key
# Vault, ACR and Postgres into it (notably Key Vault audit logging — the vault holds the
# tenant token-signing keys), and Microsoft Defender for Cloud plans for those resource
# types. Without this an attacker using stolen credentials leaves no trail.
#
# Operator prerequisites: azurerm_security_center_subscription_pricing is subscription-wide
# and singleton per resource_type — if Defender is managed centrally (Azure Policy / landing
# zone) at the subscription/management-group level, omit the defender_plans wiring here to
# avoid fighting that controller.

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.name}-aks-audit"
  target_resource_id         = var.aks_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "${var.name}-kv-audit"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${var.name}-acr-audit"
  target_resource_id         = var.acr_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "${var.name}-pg-audit"
  target_resource_id         = var.postgres_server_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}

# Microsoft Defender for Cloud (subscription-scoped, one per resource type).
resource "azurerm_security_center_subscription_pricing" "plans" {
  for_each      = toset(var.defender_plans)
  tier          = "Standard"
  resource_type = each.value
}
