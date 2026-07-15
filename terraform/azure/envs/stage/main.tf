terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# azurerm 4.x needs a subscription: set ARM_SUBSCRIPTION_ID (pipeline secret).
provider "azurerm" {
  features {}
}

module "platform" {
  source = "../../../modules/azure/stack"

  environment   = "stage"
  profile       = "hardened"
  location      = "westeurope"
  address_space = "10.72.0.0/16"
}
