resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-quiz-law-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-quiz-ai-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
}
