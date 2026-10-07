resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-quiz-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.40.0.0/20"]
  service_endpoints    = ["Microsoft.KeyVault"]
}
