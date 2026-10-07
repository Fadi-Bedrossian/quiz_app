output "server_id" {
  value = azurerm_postgresql_flexible_server.main.id
}

output "server_name" {
  value = azurerm_postgresql_flexible_server.main.name
}

output "fqdn" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

output "administrator_login" {
  value = azurerm_postgresql_flexible_server.main.administrator_login
}

output "administrator_password" {
  value     = random_password.admin.result
  sensitive = true
}
