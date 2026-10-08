resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "${var.prefix}-quiz-afd-${var.suffix}"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
}
