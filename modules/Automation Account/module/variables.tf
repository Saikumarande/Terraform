variable "expected_subscription_id" {
  nullable = false
  type     = string
  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.expected_subscription_id))
    error_message = "Supply the approved subscription GUID."
  }
}
variable "resource_group_name" {
  nullable = false
  type     = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.()-]{1,90}$", var.resource_group_name))
    error_message = "Supply a valid existing resource group name."
  }
}
variable "appname" {
  nullable = false
  type     = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,19}$", var.appname))
    error_message = "appname must be 2–20 lowercase alphanumeric characters, starting with a letter."
  }
}
variable "component" {
  nullable = false
  type     = string
  default  = "automation"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,14}$", var.component))
    error_message = "component must be 1–15 lowercase alphanumeric characters, starting with a letter."
  }
}
variable "instance_index" {
  nullable = false
  type     = string
  default  = "01"
  validation {
    condition     = can(regex("^(0[1-9]|[1-9][0-9])$", var.instance_index))
    error_message = "instance_index must be 01–99."
  }
}
variable "appenv" {
  nullable = false
  type     = string
  validation {
    condition     = contains(["dev", "sit", "uat", "ppd", "prf", "prd"], var.appenv)
    error_message = "Use dev, sit, uat, ppd, prf or prd."
  }
}
variable "location" {
  nullable = false
  type     = string
}
variable "approved_locations" {
  nullable    = false
  description = "Platform-supplied Azure location to approved three-character region code catalog."
  type        = map(string)
  validation {
    condition     = length(var.approved_locations) > 0 && alltrue([for k, v in var.approved_locations : can(regex("^[a-z0-9]{3}$", v)) && k == lower(replace(k, " ", ""))])
    error_message = "Provide a reviewed location catalog with canonical location keys and three-character codes."
  }
}
variable "owner" {
  nullable = false
  type     = string
  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner is required."
  }
}
variable "appid" {
  nullable = false
  type     = string
  validation {
    condition     = length(trimspace(var.appid)) > 0
    error_message = "appid is required."
  }
}
variable "context" {
  nullable = false
  type     = string
  validation {
    condition     = length(trimspace(var.context)) > 0
    error_message = "context is required."
  }
}
variable "application_category" {
  nullable = false
  type     = string
  validation {
    condition     = length(trimspace(var.application_category)) > 0
    error_message = "application_category is required."
  }
}
variable "tags" {
  nullable    = false
  description = "Additional tags, including a nonempty CostCentre; governed keys cannot be overridden."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for k, v in var.tags : length(k) > 0 && length(k) <= 512 && length(v) > 0 && length(v) <= 256]) && length(distinct([for k in keys(var.tags) : lower(k)])) == length(var.tags)
    error_message = "Tags must have nonempty valid lengths and no case-insensitive duplicate keys."
  }
}
variable "deployment_phase" {
  nullable    = false
  description = "bootstrap creates only the account/assets before external networking; never represents accepted private integration."
  type        = string
  default     = "integrated"
  validation {
    condition     = contains(["bootstrap", "integrated"], var.deployment_phase)
    error_message = "Use bootstrap or integrated."
  }
}
variable "private_endpoints" {
  nullable = false
  type = map(object({
    mode                         = string
    subresource_name             = string
    name                         = optional(string)
    subnet_id                    = optional(string)
    resource_group_name          = optional(string)
    location                     = optional(string)
    existing_private_endpoint_id = optional(string)
    private_dns_zone_ids         = optional(set(string), [])
  }))
  default = {}
  validation {
    condition = alltrue([for k, p in var.private_endpoints :
      can(regex("^[a-z][a-z0-9-]{0,19}$", k)) &&
      contains(["create", "existing"], p.mode) &&
      contains(["DSCAndHybridWorker", "Webhook"], p.subresource_name) &&
      length(p.private_dns_zone_ids) > 0 &&
      alltrue([for id in p.private_dns_zone_ids : can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/privatelink\\.azure-automation\\.net$", id))]) &&
      (p.mode == "create" ? (
        p.existing_private_endpoint_id == null &&
        can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$", p.subnet_id)) &&
        try(length(trimspace(p.resource_group_name)) > 0, false) &&
        try(length(trimspace(p.location)) > 0, false) &&
        (p.name == null ? true : can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,78}[A-Za-z0-9_]$", p.name)))
        ) : (
        p.subnet_id == null && p.resource_group_name == null && p.location == null && p.name == null &&
        can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/privateEndpoints/[^/]+$", p.existing_private_endpoint_id))
      ))
    ])
    error_message = "Each PE needs create/existing mode, an approved Automation subresource and expected existing DNS zone IDs; supply only the fields appropriate to its mode."
  }
}
variable "automation_variables" {
  nullable    = false
  description = "Non-secret definitions; keys select matching JSON-encoded sensitive values."
  type        = map(object({ name = string, type = string, description = string }))
  default     = {}
  validation {
    condition     = alltrue([for k, v in var.automation_variables : can(regex("^[A-Za-z][A-Za-z0-9_-]{0,127}$", v.name)) && contains(["string", "int", "bool", "datetime", "object"], v.type) && length(trimspace(v.description)) > 0]) && length(distinct([for v in values(var.automation_variables) : lower(v.name)])) == length(var.automation_variables)
    error_message = "Variables need valid names, explicit supported types, descriptions and case-insensitive uniqueness across all types."
  }
}
variable "variable_values_json" {
  nullable    = false
  description = "JSON encoding of each value, keyed exactly like automation_variables. Pipeline injects secrets; values enter state."
  type        = map(string)
  sensitive   = true
  default     = {}
}
variable "automation_credentials" {
  nullable = false
  type     = map(object({ name = string, description = string }))
  default  = {}
  validation {
    condition     = alltrue([for c in values(var.automation_credentials) : can(regex("^[A-Za-z][A-Za-z0-9_-]{0,127}$", c.name)) && length(trimspace(c.description)) > 0]) && length(distinct([for c in values(var.automation_credentials) : lower(c.name)])) == length(var.automation_credentials)
    error_message = "Credentials need valid names, descriptions and case-insensitive uniqueness."
  }
}
variable "credential_values" {
  nullable  = false
  type      = map(object({ username = string, password = string }))
  sensitive = true
  default   = {}
}
variable "customer_managed_key_id" {
  description = "Optional existing versioned Key Vault key URI. System identity must already have approved key access; configure only after account-first/RBAC deployment. Null uses service-managed encryption."
  type        = string
  default     = null
  validation {
    condition     = var.customer_managed_key_id == null ? true : can(regex("^https://[A-Za-z0-9-]+\\.vault\\.azure\\.net/keys/[^/]+/[^/]+$", var.customer_managed_key_id))
    error_message = "CMK must be an existing versioned Azure Key Vault key URI."
  }
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
  validation {
    condition     = alltrue([for id in var.governance_lock_ids : can(regex("(?i)^/subscriptions/[0-9a-f-]{36}(/resourceGroups/[^/]+(/providers/Microsoft.Automation/automationAccounts/[^/]+)?)?/providers/Microsoft.Authorization/locks/[^/]+$", id))])
    error_message = "Supply subscription, resource-group or Automation Account management-lock IDs."
  }
}
variable "rbac_dependencies" {
  nullable    = false
  description = "Optional existing deployment assignment references. Metadata verification does not prove effective access or ABAC."
  type        = map(object({ assignment_id = string, principal_id = string, scope = string, role_definition_id = string }))
  default     = {}
  validation {
    condition     = alltrue([for r in values(var.rbac_dependencies) : can(regex("(?i)^/.+/providers/Microsoft.Authorization/roleAssignments/[0-9a-f-]{36}$", r.assignment_id)) && can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", r.principal_id)) && startswith(lower(r.scope), "/subscriptions/") && can(regex("(?i)/providers/Microsoft.Authorization/roleDefinitions/[0-9a-f-]{36}$", r.role_definition_id))])
    error_message = "Supply valid existing RBAC assignment, principal, scope and role-definition references."
  }
}
variable "timeouts" {
  nullable = false
  type     = object({ create = optional(string, "30m"), read = optional(string, "5m"), update = optional(string, "30m"), delete = optional(string, "30m") })
  default  = {}
  validation {
    condition     = alltrue([for t in values(var.timeouts) : can(regex("^[1-9][0-9]*[mh]$", t))])
    error_message = "Timeouts must be positive whole-minute/hour durations, e.g. 30m."
  }
}
