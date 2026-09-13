# appgateway.tf
#
# WHAT THIS FILE DOES:
# Creates a WAF_v2 Application Gateway in front of the frontend App
# Service. Maps to Step 7 of the portal guide.
#
# This is the most complex resource in the whole project - Application
# Gateway has many interdependent pieces (listener, backend pool, HTTP
# settings, probe, routing rule) that all reference each other BY NAME
# (as plain strings), not by Terraform resource reference. That's
# different from everything else in this project and trips people up,
# so read the comments below carefully.
#
# This file also bakes in the fix for the most common real-world failure
# mode with this architecture: Application Gateway marking the backend
# "Unhealthy" because the Host header sent to App Service didn't match
# what App Service expected. `pick_host_name_from_backend_address = true`
# on the HTTP settings, below, is what fixes that.

resource "azurerm_public_ip" "appgw" {
  name                = "pip-agw-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# These four locals just give us short, readable names to reuse across the
# gateway resource below, instead of repeating long strings everywhere.
# This is optional - Terraform doesn't require it - but it makes the many
# name-based cross-references in the resource below easier to keep straight.
locals {
  appgw_name                     = "agw-3tier-${var.unique_suffix}"
  appgw_gateway_ip_config_name   = "gatewayIpConfig"
  appgw_frontend_ip_config_name  = "frontendIpConfig"
  appgw_frontend_port_name       = "port80"
  appgw_backend_pool_name        = "backendPool"
  appgw_http_settings_name       = "httpSettings"
  appgw_listener_name            = "httpListener"
  appgw_routing_rule_name        = "routingRule"
  appgw_probe_name               = "healthProbe"
}

resource "azurerm_application_gateway" "main" {
  name                = local.appgw_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = local.appgw_gateway_ip_config_name
    subnet_id = azurerm_subnet.gateway.id
  }

  frontend_ip_configuration {
    name                 = local.appgw_frontend_ip_config_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = local.appgw_frontend_port_name
    port = 80
  }

  # Unlike other resources in this project, the backend pool here points
  # at an FQDN string (the frontend App Service's hostname) rather than a
  # Terraform resource reference for the target - Application Gateway's
  # backend pools work with IP addresses or FQDNs, not "azurerm_linux_web_app"
  # objects directly. We still get automatic dependency ordering because
  # we reference azurerm_linux_web_app.frontend.default_hostname below.
  backend_address_pool {
    name  = local.appgw_backend_pool_name
    fqdns = [azurerm_linux_web_app.frontend.default_hostname]
  }

  probe {
    name                                      = local.appgw_probe_name
    protocol                                  = "Https"
    path                                      = "/"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = true

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = local.appgw_http_settings_name
    port                                = 443
    protocol                            = "Https"
    cookie_based_affinity               = "Disabled"
    request_timeout                     = 30
    # THE KEY FIX: pick the Host header from the backend pool's own FQDN,
    # rather than requiring you to manually type + maintain a matching
    # override elsewhere. This is what keeps App Service from 404-ing
    # the Gateway's health probes and real traffic.
    pick_host_name_from_backend_address = true
    probe_name                           = local.appgw_probe_name
  }

  http_listener {
    name                           = local.appgw_listener_name
    frontend_ip_configuration_name = local.appgw_frontend_ip_config_name
    frontend_port_name             = local.appgw_frontend_port_name
    protocol                       = "Http"
  }

  # This is where all the name-based references above come together:
  # the routing rule links a listener to a backend pool and HTTP settings
  # PURELY BY THE STRING NAMES you gave them above, not by Terraform
  # resource address. If you typo one of these strings, `terraform plan`
  # will NOT catch it for you at plan time the way a resource reference
  # would - it'll fail during apply instead. Double-check these match
  # exactly what you named things above.
  request_routing_rule {
    name                       = local.appgw_routing_rule_name
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.appgw_listener_name
    backend_address_pool_name  = local.appgw_backend_pool_name
    backend_http_settings_name = local.appgw_http_settings_name
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}
