resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#%*+-_=.?"
}
resource "azurerm_postgresql_flexible_server" "main" {
  name                          = "${var.prefix}-quiz-pg-${var.suffix}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = "16"
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false
  administrator_login           = "quizadmin"
  administrator_password        = random_password.admin.result
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
}
