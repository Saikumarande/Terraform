# Run using Terraform >=1.7 (mock-provider support), e.g. Terraform 1.9.8.
# OpenTofu 1.6 does not run this Terraform mock suite; use a supported test runner.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "11111111-1111-1111-1111-111111111111"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
      object_id       = "33333333-3333-3333-3333-333333333333"
    }
  }
  mock_data "azurerm_subscription" {
    defaults = { tags = { global-platform = "ctg" } }
  }
  mock_data "azurerm_resource_group" {
    defaults = { name = "rg-test", id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test" }
  }
  mock_resource "azurerm_automation_account" {
    defaults = {
      id       = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Automation/automationAccounts/aa-payments-automation-01-dev-ue2"
      identity = [{ type = "SystemAssigned", principal_id = "33333333-3333-3333-3333-333333333333", tenant_id = "22222222-2222-2222-2222-222222222222" }]
    }
  }
}
mock_provider "azapi" {}
variables {
  expected_subscription_id = "11111111-1111-1111-1111-111111111111"
  resource_group_name      = "rg-test"
  appname                  = "payments"
  appenv                   = "dev"
  location                 = "eastus2"
  approved_locations       = { eastus2 = "ue2" }
  owner                    = "test-team"
  appid                    = "test-app"
  context                  = "test"
  application_category     = "internal"
  tags                     = { CostCentre = "test" }
  deployment_phase         = "bootstrap"
}
run "bootstrap_security" {
  command = plan
  assert {
    condition     = azurerm_automation_account.this.name == "aa-payments-automation-01-dev-ue2" && azurerm_automation_account.this.sku_name == "Basic" && !azurerm_automation_account.this.public_network_access_enabled && !azurerm_automation_account.this.local_authentication_enabled && azurerm_automation_account.this.identity[0].type == "SystemAssigned"
    error_message = "Naming or fixed baseline security changed."
  }
  assert {
    condition     = !output.integration_status.private_endpoint_metadata_verified && length(azurerm_private_endpoint.this) == 0 && length(azurerm_management_lock.this) == 0
    error_message = "Bootstrap must not claim completed PE integration."
  }
}
run "all_variable_types" {
  command = plan
  variables {
    automation_variables = {
      s = { name = "Label", type = "string", description = "Label" }
      i = { name = "Retries", type = "int", description = "Count" }
      b = { name = "Enabled", type = "bool", description = "Flag" }
      d = { name = "Cutoff", type = "datetime", description = "Time" }
      o = { name = "Settings", type = "object", description = "Settings" }
    }
    variable_values_json   = { s = "\"test\"", i = "3", b = "true", d = "\"2026-10-08T00:00:00Z\"", o = "{\"retries\":3}" }
    automation_credentials = { c = { name = "Credential", description = "Test credential" } }
    credential_values      = { c = { username = "test-user", password = "nonproduction-fixture-password" } }
  }
  assert {
    condition     = length(output.variables) == 5 && alltrue([for v in values(output.variables) : v.encrypted]) && length(output.credentials) == 1
    error_message = "Typed encrypted assets were not planned correctly."
  }
  assert {
    condition     = alltrue([for v in values(output.variables) : !contains(keys(v), "value")]) && alltrue([for c in values(output.credentials) : !contains(keys(c), "password") && !contains(keys(c), "username")])
    error_message = "Outputs must contain only allowlisted asset metadata."
  }
}
run "missing_pe_rejected" {
  command = plan
  variables { deployment_phase = "integrated" }
  expect_failures = [azurerm_automation_account.this]
}
run "wrong_subscription_rejected" {
  command = plan
  variables { expected_subscription_id = "44444444-4444-4444-4444-444444444444" }
  expect_failures = [azurerm_automation_account.this]
}
run "tag_override_rejected" {
  command = plan
  variables { tags = { CostCentre = "test", owner = "unauthorised" } }
  expect_failures = [azurerm_automation_account.this]
}
run "wrong_variable_type_rejected" {
  command = plan
  variables {
    automation_variables = { a = { name = "Count", type = "int", description = "Count" } }
    variable_values_json = { a = "\"3\"" }
  }
  expect_failures = [azurerm_automation_account.this]
}
run "missing_value_rejected" {
  command = plan
  variables { automation_variables = { a = { name = "Label", type = "string", description = "Label" } } }
  expect_failures = [azurerm_automation_account.this]
}
run "duplicate_asset_rejected" {
  command = plan
  variables {
    automation_variables = {
      a = { name = "Label", type = "string", description = "Label" }
      b = { name = "label", type = "bool", description = "Flag" }
    }
    variable_values_json = { a = "\"test\"", b = "true" }
  }
  expect_failures = [var.automation_variables]
}
run "conflicting_locks_rejected" {
  command = plan
  variables {
    lock_enabled              = true
    locks_managed_by_platform = true
  }
  expect_failures = [azurerm_automation_account.this]
}
run "existing_pe_approved" {
  command = apply
  variables {
    deployment_phase = "integrated"
    private_endpoints = {
      worker = {
        mode                         = "existing", subresource_name = "DSCAndHybridWorker",
        existing_private_endpoint_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateEndpoints/pe-worker",
        private_dns_zone_ids         = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"]
      }
    }
  }
  override_data {
    target = data.azapi_resource.endpoint["worker"]
    values = { output = { properties = {
      provisioningState = "Succeeded"
      privateLinkServiceConnections = [{ properties = {
        privateLinkServiceId              = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Automation/automationAccounts/aa-payments-automation-01-dev-ue2"
        groupIds                          = ["DSCAndHybridWorker"]
        privateLinkServiceConnectionState = { status = "Approved" }
      } }]
    } } }
  }
  override_data {
    target = data.azapi_resource_list.dns_groups["worker"]
    values = { output = { value = [{ properties = {
      privateDnsZoneConfigs = [{ properties = {
        privateDnsZoneId = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"
      } }]
    } }] } }
  }
  assert {
    condition     = output.integration_status.private_endpoint_metadata_verified && length(azurerm_private_endpoint.this) == 0 && !output.private_endpoints["worker"].created
    error_message = "External PE must be verified without managed ownership."
  }
}
run "existing_pe_wrong_target" {
  command = apply
  variables {
    deployment_phase = "integrated"
    private_endpoints = {
      worker = {
        mode                         = "existing", subresource_name = "DSCAndHybridWorker",
        existing_private_endpoint_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateEndpoints/pe-worker",
        private_dns_zone_ids         = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"]
      }
    }
  }
  override_data {
    target = data.azapi_resource.endpoint["worker"]
    values = { output = { properties = {
      provisioningState = "Succeeded"
      privateLinkServiceConnections = [{ properties = {
        privateLinkServiceId              = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Automation/automationAccounts/wrong-account"
        groupIds                          = ["DSCAndHybridWorker"]
        privateLinkServiceConnectionState = { status = "Approved" }
      } }]
    } } }
  }
  expect_failures = [data.azapi_resource.endpoint["worker"]]
}
run "created_pe_approved" {
  command = apply
  variables {
    deployment_phase = "integrated"
    private_endpoints = {
      worker = {
        mode                 = "create", subresource_name = "DSCAndHybridWorker",
        subnet_id            = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/pe"
        resource_group_name  = "rg-network"
        location             = "eastus2"
        private_dns_zone_ids = ["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"]
      }
    }
  }
  override_data {
    target = data.azapi_resource.subnet["worker"]
    values = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet/subnets/pe" }
  }
  override_data {
    target = data.azapi_resource.dns_zone["/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"]
    values = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net" }
  }
  override_data {
    target = data.azapi_resource.endpoint["worker"]
    values = { output = { properties = {
      provisioningState = "Succeeded"
      privateLinkServiceConnections = [{ properties = {
        privateLinkServiceId              = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Automation/automationAccounts/aa-payments-automation-01-dev-ue2"
        groupIds                          = ["DSCAndHybridWorker"]
        privateLinkServiceConnectionState = { status = "Approved" }
      } }]
    } } }
  }
  override_data {
    target = data.azapi_resource_list.dns_groups["worker"]
    values = { output = { value = [{ properties = {
      privateDnsZoneConfigs = [{ properties = {
        privateDnsZoneId = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azure-automation.net"
      } }]
    } }] } }
  }
  assert {
    condition     = output.integration_status.private_endpoint_metadata_verified && length(azurerm_private_endpoint.this) == 1 && output.private_endpoints["worker"].created
    error_message = "Created PE must target the account and use the approved DNS zone."
  }
}
