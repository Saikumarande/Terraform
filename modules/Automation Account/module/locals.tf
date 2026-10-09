locals {
  location     = lower(replace(var.location, " ", ""))
  region_code  = lookup(var.approved_locations, local.location, "invalid")
  account_name = "aa-${var.appname}-${var.component}-${var.instance_index}-${var.appenv}-${local.region_code}"
  subscription_tags = {
    for k, v in data.azurerm_subscription.current.tags : k => v if startswith(lower(k), "global-")
  }
  governed_tags = merge(local.subscription_tags, {
    Application = var.appname, ApplicationId = var.appid, Environment = var.appenv,
    Owner       = var.owner, Context = var.context, ApplicationCategory = var.application_category
  })
  effective_tags = merge(var.tags, local.governed_tags)
  create_pe      = { for k, p in var.private_endpoints : k => p if p.mode == "create" }
  existing_pe    = { for k, p in var.private_endpoints : k => p if p.mode == "existing" }
  decoded_values = { for k in keys(var.automation_variables) : k => try(jsondecode(var.variable_values_json[k]), null) }
  values_valid = alltrue([for k, d in var.automation_variables : try(
    d.type == "string" ? startswith(trimspace(var.variable_values_json[k]), "\"") :
    d.type == "bool" ? contains(["true", "false"], trimspace(var.variable_values_json[k])) :
    d.type == "int" ? (can(regex("^-?(0|[1-9][0-9]*)$", trimspace(var.variable_values_json[k]))) && local.decoded_values[k] >= -2147483648 && local.decoded_values[k] <= 2147483647) :
    d.type == "datetime" ? (startswith(trimspace(var.variable_values_json[k]), "\"") && can(formatdate("YYYY", local.decoded_values[k]))) :
    d.type == "object" ? startswith(trimspace(var.variable_values_json[k]), "{") : false,
    false
  ) && can(jsondecode(lookup(var.variable_values_json, k, "")))])
  endpoints = merge(
    { for k, p in azurerm_private_endpoint.this : k => p.id },
    { for k, p in local.existing_pe : k => p.existing_private_endpoint_id }
  )
}
