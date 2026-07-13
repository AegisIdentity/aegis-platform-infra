terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
    }
  }
  # backend "azurerm" { resource_group_name = "aegis-tfstate" storage_account_name = "aegistfstate" container_name = "tfstate" key = "azure.tfstate" }
}

provider "azurerm" {
  features {}
}
