terraform {
  # Remote state per environment. Bootstrap the storage account once, then
  # uncomment. State is isolated per environment by key.
  # backend "azurerm" {
  #   resource_group_name  = "aegis-tfstate"
  #   storage_account_name = "aegistfstate"
  #   container_name       = "tfstate"
  #   key                  = "azure-stage.tfstate"
  #   use_azuread_auth     = true
  # }
}
