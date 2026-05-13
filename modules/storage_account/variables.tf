variable "resource_group_name" {
  description = "The name of the resource group in which to create the storage account."
  type        = string
  default     = "DEVASKINFRG1002" 

}

variable "location" {
  description = "The Azure region where the storage account should be created."
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "The name of the storage account. Must be unique across Azure."
  type        = string
  default     = "devaskinfsa01"  
}

variable "account_tier" {
  description = "The tier of the storage account."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "The replication type for the storage account."
  type        = string
  default     = "LRS"
}

variable "enable_https_traffic_only" {
  description = "Whether to enable HTTPS traffic only."
  type        = bool
  default     = true
}

variable "min_tls_version" {
  description = "The minimum TLS version to be permitted."
  type        = string
  default     = "TLS1_2"
}

variable "enable_versioning" {
  description = "Whether to enable blob versioning."
  type        = bool
  default     = true
}

variable "enable_soft_delete" {
  description = "Whether to enable soft delete for blobs."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "The number of days to retain soft deleted blobs."
  type        = number
  default     = 7
}

variable "tags" {
  description = "A map of tags to assign to the storage account."
  type        = map(string)
  default     = {}
}