output "storage_account_name" {
  description = "The name of the deployed storage account."
  value       = module.storage_account.storage_account_name
}

output "storage_account_id" {
  description = "The Azure resource ID of the storage account."
  value       = module.storage_account.storage_account_id
}

output "primary_access_key" {
  description = "The primary access key for the storage account."
  value       = module.storage_account.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "The primary connection string for the storage account."
  value       = module.storage_account.primary_connection_string
  sensitive   = true
}
