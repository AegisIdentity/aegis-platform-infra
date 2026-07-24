terraform {
  # Remote state per environment (H8). State holds the Postgres admin password — it
  # must live in the encrypted, RBAC-controlled azurerm backend, never an unencrypted
  # local terraform.tfstate.
  #
  # Bootstrap ONCE before the first apply (see terraform/README.md): create the storage
  # account (blob versioning + soft delete, public access disabled, Azure AD auth) and
  # the tfstate container, then init with the globally-unique account name via partial
  # config:
  #
  #   terraform init -backend-config="storage_account_name=aegistfstate<suffix>"
  #
  # CI must pass -backend-config; an init without it fails rather than silently writing
  # local state.
  backend "azurerm" {
    resource_group_name = "aegis-tfstate"
    # storage_account_name — supplied at init via -backend-config (globally unique)
    container_name   = "tfstate"
    key              = "azure-stage.tfstate"
    use_azuread_auth = true
  }
}
