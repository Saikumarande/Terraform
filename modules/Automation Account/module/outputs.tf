output "automation_account_id" { value = azurerm_automation_account.this.id }
output "automation_account_name" { value = azurerm_automation_account.this.name }
output "account" {
  value = {
    id                            = azurerm_automation_account.this.id, name = azurerm_automation_account.this.name,
    subscription_id               = data.azurerm_client_config.current.subscription_id,
    resource_group_name           = azurerm_automation_account.this.resource_group_name,
    location                      = local.location, region_code = local.region_code, appenv = var.appenv,
    sku                           = "Basic", tags = local.effective_tags, created = true,
    public_network_access_enabled = false, local_authentication_enabled = false,
    encryption_mode               = var.customer_managed_key_id == null ? "ServiceManaged" : "CustomerManaged"
  }
}
output "identity" {
  value = {
    type                = "SystemAssigned", principal_id = azurerm_automation_account.this.identity[0].principal_id,
    tenant_id           = azurerm_automation_account.this.identity[0].tenant_id,
    account_resource_id = azurerm_automation_account.this.id
  }
}
output "variables" {
  value = { for k, d in var.automation_variables : k => {
    id   = merge(azurerm_automation_variable_string.this, azurerm_automation_variable_int.this, azurerm_automation_variable_bool.this, azurerm_automation_variable_datetime.this, azurerm_automation_variable_object.this)[k].id,
    name = d.name, type = d.type, encrypted = true, created = true
  } }
}
output "credentials" {
  value = { for k, d in var.automation_credentials : k => {
    id = azurerm_automation_credential.this[k].id, name = d.name, type = "PSCredential", created = true
  } }
}
output "private_endpoints" {
  value = { for k, p in var.private_endpoints : k => {
    id                    = local.endpoints[k], target_id = azurerm_automation_account.this.id,
    mode                  = p.mode, created = p.mode == "create", subresource = p.subresource_name,
    expected_dns_zone_ids = p.private_dns_zone_ids,
    provisioning_state    = data.azapi_resource.endpoint[k].output.properties.provisioningState,
    connections           = concat(try(data.azapi_resource.endpoint[k].output.properties.privateLinkServiceConnections, []), try(data.azapi_resource.endpoint[k].output.properties.manualPrivateLinkServiceConnections, [])),
    dns_configs           = try(data.azapi_resource.endpoint[k].output.properties.customDnsConfigs, []),
    dns_zone_groups       = try(data.azapi_resource_list.dns_groups[k].output.value, [])
  } }
  depends_on = [data.azapi_resource.endpoint, data.azapi_resource_list.dns_groups]
}
output "integration_status" {
  value = {
    phase                              = var.deployment_phase,
    private_endpoint_metadata_verified = var.deployment_phase == "integrated",
    dns_connectivity_acceptance        = "Requires separate QA test from the approved private execution network"
  }
  depends_on = [data.azapi_resource.endpoint, data.azapi_resource_list.dns_groups]
}
output "governance" {
  value = {
    owner             = var.owner,
    module_lock_id    = try(azurerm_management_lock.this[0].id, null),
    external_lock_ids = var.governance_lock_ids,
    rbac_dependencies = var.rbac_dependencies
  }
}
