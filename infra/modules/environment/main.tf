resource "azurerm_postgresql_flexible_server_database" "env" {
  name      = "quiz_${var.environment}"
  server_id = var.postgres_server_id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "${var.prefix}-quiz-${var.environment}-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "workload" {
  name      = "quiz-${var.environment}-api"
  parent_id = azurerm_user_assigned_identity.workload.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = var.aks_oidc_issuer_url
  subject   = "system:serviceaccount:quiz-${var.environment}:quiz-api"
}

resource "azurerm_role_assignment" "kv" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}

resource "azurerm_user_assigned_identity" "deploy" {
  name                = "${var.prefix}-quiz-${var.environment}-gha-deploy"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "deploy" {
  name      = "github-${var.environment}"
  parent_id = azurerm_user_assigned_identity.deploy.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_owner}/${var.github_repo}:environment:${var.environment}"
}

resource "azurerm_role_assignment" "deploy_aks_user" {
  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

resource "azurerm_role_assignment" "deploy_aks_rbac" {
  scope                = var.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

resource "azurerm_role_assignment" "deploy_acr" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}

resource "azurerm_public_ip" "web" {
  name                = "${var.prefix}-quiz-${var.environment}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.prefix}-quiz-${var.environment}-${var.name_suffix}"
}

resource "azurerm_cdn_frontdoor_endpoint" "env" {
  name                     = "${var.prefix}-quiz-${var.environment}-${var.name_suffix}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
}

resource "azurerm_cdn_frontdoor_origin_group" "env" {
  name                     = "${var.environment}-origin-group"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
  session_affinity_enabled = false

  health_probe {
    interval_in_seconds = 30
    path                = "/healthz"
    protocol            = "Http"
    request_type        = "GET"
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "env" {
  name                           = "${var.environment}-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.env.id
  enabled                        = true
  host_name                      = azurerm_public_ip.web.fqdn
  origin_host_header             = azurerm_public_ip.web.fqdn
  http_port                      = 80
  https_port                     = 443
  certificate_name_check_enabled = false
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "env" {
  name                          = "${var.environment}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.env.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.env.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.env.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpOnly"
  link_to_default_domain        = true
  https_redirect_enabled        = true
}
