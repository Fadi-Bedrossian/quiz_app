resource "azurerm_cdn_frontdoor_endpoint" "web" {
  name                     = "${var.prefix}-quiz-${var.environment}-${var.name_suffix}"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id
  enabled                  = true
}

resource "azurerm_cdn_frontdoor_origin_group" "web" {
  name                     = "${var.environment}-origin-group"
  cdn_frontdoor_profile_id = var.frontdoor_profile_id

  health_probe {
    interval_in_seconds = 30
    path                = "/healthz"
    protocol            = "Http"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "web" {
  name                          = "${var.environment}-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  enabled                       = true

  certificate_name_check_enabled = false
  host_name                      = azurerm_public_ip.web.fqdn
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_public_ip.web.fqdn
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "web" {
  name                          = "${var.environment}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.web.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.web.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.web.id]
  enabled                       = true

  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]
  link_to_default_domain = true
}
