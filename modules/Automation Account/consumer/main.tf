module "automation_account" {
  # Local package example. Replace with your approved JFrog module source/version.
  source                   = "../module"
  providers                = { azurerm = azurerm, azapi = azapi }
  expected_subscription_id = var.subscription_id
  resource_group_name      = var.resource_group_name
  location                 = var.location
  approved_locations       = var.approved_locations
  appname                  = "payments"
  component                = "automation"
  instance_index           = "01"
  appenv                   = "dev"
  appid                    = var.appid
  owner                    = var.owner
  context                  = var.context
  application_category     = var.application_category
  tags                     = { CostCentre = var.cost_centre }
  deployment_phase         = var.deployment_phase
  private_endpoints = var.deployment_phase == "bootstrap" ? {} : {
    worker = {
      mode                         = var.pe_mode
      subresource_name             = "DSCAndHybridWorker"
      subnet_id                    = var.pe_mode == "create" ? var.pe_subnet_id : null
      resource_group_name          = var.pe_mode == "create" ? var.pe_resource_group_name : null
      location                     = var.pe_mode == "create" ? var.pe_location : null
      existing_private_endpoint_id = var.pe_mode == "existing" ? var.existing_private_endpoint_id : null
      private_dns_zone_ids         = var.private_dns_zone_ids
    }
  }
  automation_variables      = var.automation_variables
  variable_values_json      = var.variable_values_json
  automation_credentials    = var.automation_credentials
  credential_values         = var.credential_values
  customer_managed_key_id   = var.customer_managed_key_id
  lock_enabled              = var.lock_enabled
  locks_managed_by_platform = var.locks_managed_by_platform
  governance_lock_ids       = var.governance_lock_ids
  rbac_dependencies         = var.rbac_dependencies
}
