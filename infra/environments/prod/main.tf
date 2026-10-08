data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group
    storage_account_name = var.tfstate_storage_account
    container_name       = var.tfstate_container
    key                  = "shared.tfstate"
    use_azuread_auth     = true
  }
}

module "environment" {
  source              = "../../modules/environment"
  subscription_id     = var.subscription_id
  prefix              = var.prefix
  environment         = var.environment
  location            = var.location
  resource_group_name = var.resource_group_name
  github_owner        = var.github_owner
  github_repo         = var.github_repo
  github_owner_id     = var.github_owner_id
  github_repo_id      = var.github_repo_id
  aks_oidc_issuer_url = data.terraform_remote_state.shared.outputs.aks_oidc_issuer_url
  aks_id              = data.terraform_remote_state.shared.outputs.aks_id
  acr_id              = data.terraform_remote_state.shared.outputs.acr_id
  acr_name            = data.terraform_remote_state.shared.outputs.acr_name
  acr_login_server    = data.terraform_remote_state.shared.outputs.acr_login_server
  key_vault_id        = data.terraform_remote_state.shared.outputs.key_vault_id
  key_vault_name      = data.terraform_remote_state.shared.outputs.key_vault_name
  name_suffix         = data.terraform_remote_state.shared.outputs.name_suffix
}


resource "azurerm_public_ip" "monitoring" {
  name                = "${var.prefix}-quiz-monitoring-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-quiz-monitoring-${data.terraform_remote_state.shared.outputs.name_suffix}"

  tags = {
    component   = "observability"
    environment = "prod"
  }
}
