# appservice.tf
#
# WHAT THIS FILE DOES:
# Creates one shared App Service Plan and two Linux Web Apps (backend/app
# tier, frontend/web tier), each VNet-integrated into its own subnet.
# Maps to Steps 5-6 of the portal guide.

# --- App Service Plan ---
# Standard S1 is the minimum tier that supports BOTH Regional VNet
# Integration and autoscale - Basic tier supports neither.
resource "azurerm_service_plan" "main" {
  name                = "asp-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# --- Backend (app tier) ---
resource "azurerm_linux_web_app" "backend" {
  name                = "app-3tier-backend-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  # This single line is what "VNet-integrates" the app - no separate
  # resource needed (older Terraform/azurerm versions required a
  # standalone azurerm_app_service_virtual_network_swift_connection
  # resource; the current provider lets you set it directly here).
  virtual_network_subnet_id = azurerm_subnet.app.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }

    # Access restriction: ONLY traffic from the web subnet may reach this
    # app. ip_restriction_default_action = "Deny" means "block everything
    # not explicitly allowed below" - without that line, Azure's default
    # is to allow all traffic and just prioritize your rules underneath it.
    ip_restriction_default_action = "Deny"

    ip_restriction {
      name                      = "Allow-Web-Subnet"
      action                    = "Allow"
      priority                  = 100
      virtual_network_subnet_id = azurerm_subnet.web.id
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "WEBSITE_VNET_ROUTE_ALL"                = "1" # forces ALL outbound traffic through the VNet, not just private IP ranges
  }

  # A `connection_string` block is a nested block, just like site_config -
  # you can have several of these if you had more than one DB.
  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = local.sql_connection_string
  }
}

# --- Frontend (web tier) ---
resource "azurerm_linux_web_app" "frontend" {
  name                = "app-3tier-frontend-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id

  virtual_network_subnet_id = azurerm_subnet.web.id

  site_config {
    always_on = true

    application_stack {
      node_version = "18-lts"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    # Note: this references the BACKEND app's default_hostname attribute.
    # Terraform automatically waits for azurerm_linux_web_app.backend to
    # be created before it can know this value, and creates the frontend
    # app AFTER the backend as a result - another example of dependencies
    # being inferred from references rather than declared manually.
    "BACKEND_URL" = "https://${azurerm_linux_web_app.backend.default_hostname}"
  }
}
