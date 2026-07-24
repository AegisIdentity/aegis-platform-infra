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

# H9: hardened AKS must use Entra ID RBAC with local accounts disabled. No default —
# `terraform plan` fails until the real stage cluster-admin group object IDs are supplied
# (e.g. TF_VAR_admin_group_object_ids='["<group-guid>"]' or a *.tfvars). Do NOT default
# this to [], which would silently re-enable static local admin credentials.
variable "admin_group_object_ids" {
  type        = list(string)
  description = "Entra ID group object IDs granted Azure RBAC cluster admin on the stage AKS cluster."
}

module "platform" {
  source = "../../../modules/azure/stack"

  environment            = "stage"
  profile                = "hardened"
  location               = "westeurope"
  address_space          = "10.72.0.0/16"
  admin_group_object_ids = var.admin_group_object_ids
}
