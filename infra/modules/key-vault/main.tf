resource "azurerm_key_vault" "main" {
  name                       = "${var.prefix}-quiz-kv-${var.suffix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    virtual_network_subnet_ids = [var.aks_subnet_id]
    ip_rules                   = var.ci_runner_ip == "" ? [] : [var.ci_runner_ip]
  }
}
resource "azurerm_role_assignment" "secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.secrets_officer_principal_id
}
resource "time_sleep" "rbac_propagation" {
  create_duration = "30s"
  depends_on      = [azurerm_role_assignment.secrets_officer]
}
resource "azurerm_key_vault_secret" "postgres" {
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.rbac_propagation]
}
resource "azurerm_key_vault_secret" "appinsights" {
  name         = "appinsights-connection-string"
  value        = var.appinsights_connection_string
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [time_sleep.rbac_propagation]
}
