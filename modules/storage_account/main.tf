resource "azurerm_storage_account" "storage_account" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = "StorageV2"

  enable_https_traffic_only = var.enable_https_traffic_only
  min_tls_version           = var.min_tls_version

  blob_properties {
    versioning_enabled  = var.enable_versioning
    delete_retention_policy {
      days = var.enable_soft_delete ? var.soft_delete_retention_days : null
    }
  }

  tags = var.tags
}