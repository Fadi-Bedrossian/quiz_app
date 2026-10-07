data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "infra" {
  name                = "sg-gha-terraform"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "network" {
  source              = "../modules/network"
  prefix              = var.prefix
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

module "monitoring" {
  source              = "../modules/monitoring"
  prefix              = var.prefix
  suffix              = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

module "database" {
  source              = "../modules/database"
  prefix              = var.prefix
  suffix              = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  delegated_subnet_id = module.network.postgres_subnet_id
  private_dns_zone_id = module.network.postgres_private_dns_zone_id
  depends_on          = [module.network]
}

module "registry" {
  source              = "../modules/registry"
  prefix              = var.prefix
  suffix              = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

module "key_vault" {
  source                        = "../modules/key-vault"
  prefix                        = var.prefix
  suffix                        = random_string.suffix.result
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.main.name
  tenant_id                     = var.tenant_id
  secrets_officer_principal_id  = data.azurerm_user_assigned_identity.infra.principal_id
  postgres_admin_password       = module.database.administrator_password
  appinsights_connection_string = module.monitoring.appinsights_connection_string
}

module "aks" {
  source                     = "../modules/aks"
  prefix                     = var.prefix
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.main.name
  resource_group_id          = data.azurerm_resource_group.main.id
  tenant_id                  = var.tenant_id
  subnet_id                  = module.network.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  acr_id                     = module.registry.id
}

module "frontdoor" {
  source              = "../modules/frontdoor-profile"
  prefix              = var.prefix
  resource_group_name = data.azurerm_resource_group.main.name
}
