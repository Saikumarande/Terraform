# Authentication comes from Harness/OIDC or approved ARM_* environment variables.
provider "azurerm" {
  features {}
  subscription_id                 = var.subscription_id
  tenant_id                       = var.tenant_id
  resource_provider_registrations = "none"
}
provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}
