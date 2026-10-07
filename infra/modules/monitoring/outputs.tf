output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "appinsights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}
