terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}


# Deploy the storage account module with all defaults
module "storage_account" {
  source = "../modules/storage_account"

 # resource_group_name = azurerm_resource_group.rg.name
 # location            = azurerm_resource_group.rg.location
  # All other values use defaults
}