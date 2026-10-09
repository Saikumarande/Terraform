variable "subscription_id" {
  nullable = false
  type     = string
}
variable "tenant_id" {
  nullable = false
  type     = string
}
variable "resource_group_name" {
  nullable = false
  type     = string
}
variable "location" {
  nullable = false
  type     = string
}
variable "approved_locations" {
  nullable = false
  type     = map(string)
}
variable "owner" {
  nullable = false
  type     = string
}
variable "appid" {
  nullable = false
  type     = string
}
variable "context" {
  nullable = false
  type     = string
}
variable "application_category" {
  nullable = false
  type     = string
}
variable "cost_centre" {
  nullable = false
  type     = string
}
variable "deployment_phase" {
  nullable = false
  type     = string
  default  = "integrated"
}
variable "pe_mode" {
  nullable = false
  type     = string
  default  = "create"
  validation {
    condition     = contains(["create", "existing"], var.pe_mode)
    error_message = "pe_mode must be create or existing."
  }
}
variable "pe_subnet_id" {
  type    = string
  default = null
}
variable "pe_resource_group_name" {
  type    = string
  default = null
}
variable "pe_location" {
  type    = string
  default = null
}
variable "existing_private_endpoint_id" {
  type    = string
  default = null
}
variable "private_dns_zone_ids" {
  nullable = false
  type     = set(string)
  default  = []
}
variable "lock_enabled" {
  nullable = false
  type     = bool
  default  = false
}
variable "locks_managed_by_platform" {
  nullable = false
  type     = bool
  default  = false
}
variable "governance_lock_ids" {
  nullable = false
  type     = set(string)
  default  = []
}
variable "customer_managed_key_id" {
  type    = string
  default = null
}
# Leave these definitions empty unless the corresponding values are securely injected.
variable "automation_variables" {
  nullable = false
  type     = map(object({ name = string, type = string, description = string }))
  default  = {}
}
variable "variable_values_json" {
  nullable  = false
  type      = map(string)
  sensitive = true
  default   = {}
}
variable "automation_credentials" {
  nullable = false
  type     = map(object({ name = string, description = string }))
  default  = {}
}
variable "credential_values" {
  nullable  = false
  type      = map(object({ username = string, password = string }))
  sensitive = true
  default   = {}
}
variable "rbac_dependencies" {
  nullable = false
  type     = map(object({ assignment_id = string, principal_id = string, scope = string, role_definition_id = string }))
  default  = {}
}
