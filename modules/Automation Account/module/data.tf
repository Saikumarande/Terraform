data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}
data "azurerm_resource_group" "account" { name = var.resource_group_name }

data "azapi_resource" "subnet" {
  for_each               = local.create_pe
  type                   = "Microsoft.Network/virtualNetworks/subnets@2023-11-01"
  resource_id            = each.value.subnet_id
  response_export_values = ["id"]
}
data "azapi_resource" "dns_zone" {
  for_each               = toset(flatten([for p in values(var.private_endpoints) : tolist(p.private_dns_zone_ids)]))
  type                   = "Microsoft.Network/privateDnsZones@2020-06-01"
  resource_id            = each.value
  response_export_values = ["id", "name"]
}
data "azapi_resource" "rbac" {
  for_each               = var.rbac_dependencies
  type                   = "Microsoft.Authorization/roleAssignments@2022-04-01"
  resource_id            = each.value.assignment_id
  response_export_values = ["properties"]
  lifecycle {
    postcondition {
      condition     = lower(self.output.properties.principalId) == lower(each.value.principal_id) && lower(self.output.properties.scope) == lower(each.value.scope) && lower(self.output.properties.roleDefinitionId) == lower(each.value.role_definition_id)
      error_message = "Referenced RBAC assignment does not match its declared principal, scope or role."
    }
  }
}
# Read the actual PE ARM metadata; never adopt an external PE as a managed resource.
data "azapi_resource" "endpoint" {
  for_each               = var.private_endpoints
  type                   = "Microsoft.Network/privateEndpoints@2023-11-01"
  resource_id            = local.endpoints[each.key]
  response_export_values = ["properties.provisioningState", "properties.privateLinkServiceConnections", "properties.manualPrivateLinkServiceConnections", "properties.customDnsConfigs", "properties.networkInterfaces"]
  depends_on             = [azurerm_automation_account.this, azurerm_private_endpoint.this]
  lifecycle {
    postcondition {
      condition     = try(self.output.properties.provisioningState == "Succeeded", false)
      error_message = "PE provisioning has not succeeded."
    }
    postcondition {
      condition = anytrue([for c in concat(try(self.output.properties.privateLinkServiceConnections, []), try(self.output.properties.manualPrivateLinkServiceConnections, [])) :
        try(lower(c.properties.privateLinkServiceId) == lower(azurerm_automation_account.this.id) && contains(c.properties.groupIds, each.value.subresource_name) && c.properties.privateLinkServiceConnectionState.status == "Approved", false)
      ])
      error_message = "PE must have an Approved connection to this account and the requested Automation subresource."
    }
  }
}
data "azapi_resource_list" "dns_groups" {
  for_each               = var.private_endpoints
  type                   = "Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01"
  parent_id              = local.endpoints[each.key]
  response_export_values = ["value"]
  depends_on             = [data.azapi_resource.endpoint]
  lifecycle {
    postcondition {
      condition = alltrue([for zone in each.value.private_dns_zone_ids : contains(
        flatten([for group in try(self.output.value, []) : [for config in try(group.properties.privateDnsZoneConfigs, []) : lower(config.properties.privateDnsZoneId)]]), lower(zone)
      )])
      error_message = "PE does not have the required private DNS zone association."
    }
  }
}
data "azapi_resource" "platform_lock" {
  for_each               = var.governance_lock_ids
  type                   = "Microsoft.Authorization/locks@2016-09-01"
  resource_id            = each.value
  response_export_values = ["properties.level"]
  depends_on             = [azurerm_automation_account.this]
  lifecycle {
    postcondition {
      condition = contains(["CanNotDelete", "ReadOnly"], self.output.properties.level) && contains([
        lower(azurerm_automation_account.this.id), lower(data.azurerm_resource_group.account.id),
        "/subscriptions/${lower(var.expected_subscription_id)}"
      ], split("/providers/microsoft.authorization/locks/", lower(each.value))[0])
      error_message = "Platform lock must exist at the account, its resource group or subscription scope."
    }
  }
}
