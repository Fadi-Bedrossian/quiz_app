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

resource "random_password" "postgres_admin" {
  length           = 32
  special          = true
  override_special = "!#%*+-_=.?"
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

module "registry" {
  source              = "../modules/registry"
  prefix              = var.prefix
  suffix              = random_string.suffix.result
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
}

module "frontdoor" {
  source              = "../modules/frontdoor"
  prefix              = var.prefix
  suffix              = random_string.suffix.result
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
  postgres_admin_password       = random_password.postgres_admin.result
  appinsights_connection_string = module.monitoring.appinsights_connection_string
  aks_subnet_id                 = module.network.aks_subnet_id
  ci_runner_ip                  = var.ci_runner_ip
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
  node_vm_size               = var.node_vm_size
}
