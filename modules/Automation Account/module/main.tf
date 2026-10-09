resource "azurerm_automation_account" "this" {
  name                          = local.account_name
  resource_group_name           = data.azurerm_resource_group.account.name
  location                      = local.location
  sku_name                      = "Basic"
  public_network_access_enabled = false
  local_authentication_enabled  = false
  tags                          = local.effective_tags
  identity { type = "SystemAssigned" }
  dynamic "encryption" {
    for_each = var.customer_managed_key_id == null ? [] : [var.customer_managed_key_id]
    content { key_vault_key_id = encryption.value }
  }
  timeouts {
    create = var.timeouts.create
    read   = var.timeouts.read
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
  depends_on = [data.azapi_resource.rbac]
  lifecycle {
    precondition {
      condition     = lower(data.azurerm_client_config.current.subscription_id) == lower(var.expected_subscription_id)
      error_message = "Provider subscription differs from expected_subscription_id."
    }
    precondition {
      condition     = contains(keys(var.approved_locations), local.location) && can(regex("^[a-z][a-z0-9-]{4,48}[a-z0-9]$", local.account_name))
      error_message = "Location is unapproved or generated account name violates the 6–50-character naming contract."
    }
    precondition {
      condition     = length(local.subscription_tags) > 0 && alltrue([for v in values(local.subscription_tags) : length(trimspace(v)) > 0])
      error_message = "Subscription needs nonempty governed global-* tags."
    }
    precondition {
      condition     = length(distinct([for k in keys(local.governed_tags) : lower(k)])) == length(local.governed_tags) && length(setintersection(toset([for k in keys(var.tags) : lower(k)]), toset([for k in keys(local.governed_tags) : lower(k)]))) == 0 && try(length(trimspace(var.tags["CostCentre"])) > 0, false) && length(local.effective_tags) <= 50 && alltrue([for k, v in local.effective_tags : length(k) <= 512 && length(v) <= 256])
      error_message = "Supply CostCentre; do not override governed tags, duplicate tag keys by case, or exceed 50 tags."
    }
    precondition {
      condition     = var.deployment_phase == "integrated" ? length(var.private_endpoints) > 0 : length(var.private_endpoints) == 0
      error_message = "integrated requires PE entries; bootstrap is an explicit account-only stage with no PE entries."
    }
    precondition {
      condition     = !(var.lock_enabled && var.locks_managed_by_platform) && (!var.locks_managed_by_platform || length(var.governance_lock_ids) > 0)
      error_message = "Do not duplicate platform locks; provide their references when platform lock ownership is selected."
    }
    precondition {
      condition     = nonsensitive(toset(keys(var.variable_values_json))) == toset(keys(var.automation_variables)) && local.values_valid
      error_message = "Variable values must match definition keys and JSON types (int32, RFC3339 datetime, JSON object); values are not included in this error."
    }
    precondition {
      condition     = nonsensitive(toset(keys(var.credential_values))) == toset(keys(var.automation_credentials)) && alltrue([for c in values(var.credential_values) : length(trimspace(c.username)) > 0 && length(trimspace(c.password)) > 0 && trimspace(c.password) != "****"])
      error_message = "Supply exactly matching credential keys with nonempty usernames/passwords, not placeholder passwords."
    }
  }
}
resource "azurerm_private_endpoint" "this" {
  for_each            = local.create_pe
  name                = coalesce(each.value.name, "pe-${local.account_name}-${each.key}")
  resource_group_name = each.value.resource_group_name
  location            = each.value.location
  subnet_id           = data.azapi_resource.subnet[each.key].id
  tags                = local.effective_tags
  private_service_connection {
    name                           = "psc-${each.key}"
    private_connection_resource_id = azurerm_automation_account.this.id
    subresource_names              = [each.value.subresource_name]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "automation"
    private_dns_zone_ids = [for id in each.value.private_dns_zone_ids : data.azapi_resource.dns_zone[id].id]
  }
}
resource "azurerm_automation_variable_string" "this" {
  for_each                = { for k, v in var.automation_variables : k => v if v.type == "string" }
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  encrypted               = true
  value                   = try(local.decoded_values[each.key], "")
}
resource "azurerm_automation_variable_int" "this" {
  for_each                = { for k, v in var.automation_variables : k => v if v.type == "int" }
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  encrypted               = true
  value                   = try(tonumber(local.decoded_values[each.key]), 0)
}
resource "azurerm_automation_variable_bool" "this" {
  for_each                = { for k, v in var.automation_variables : k => v if v.type == "bool" }
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  encrypted               = true
  value                   = try(tobool(local.decoded_values[each.key]), false)
}
resource "azurerm_automation_variable_datetime" "this" {
  for_each                = { for k, v in var.automation_variables : k => v if v.type == "datetime" }
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  encrypted               = true
  value                   = try(local.decoded_values[each.key], "2000-01-01T00:00:00Z")
}
resource "azurerm_automation_variable_object" "this" {
  for_each                = { for k, v in var.automation_variables : k => v if v.type == "object" }
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  encrypted               = true
  value                   = try(jsonencode(local.decoded_values[each.key]), "{}")
}
resource "azurerm_automation_credential" "this" {
  for_each                = var.automation_credentials
  name                    = each.value.name
  description             = each.value.description
  resource_group_name     = azurerm_automation_account.this.resource_group_name
  automation_account_name = azurerm_automation_account.this.name
  username                = try(var.credential_values[each.key].username, "")
  password                = try(var.credential_values[each.key].password, "")
}
# Remove this lock in a separate reviewed apply before destroying the account.
resource "azurerm_management_lock" "this" {
  count      = var.lock_enabled ? 1 : 0
  name       = "automation-account-delete-protection"
  scope      = azurerm_automation_account.this.id
  lock_level = "CanNotDelete"
  notes      = "Managed by the account module; coordinate removal with dependency owners."
  depends_on = [azurerm_automation_variable_string.this, azurerm_automation_variable_int.this, azurerm_automation_variable_bool.this, azurerm_automation_variable_datetime.this, azurerm_automation_variable_object.this, azurerm_automation_credential.this, data.azapi_resource_list.dns_groups]
}
