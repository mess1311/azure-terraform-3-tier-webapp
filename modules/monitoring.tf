# monitoring.tf
#
# WHAT THIS FILE DOES:
# Creates a Log Analytics workspace and a workspace-based Application
# Insights instance. Maps to Step 9 of the portal guide. Created before
# the App Services (below) so their connection strings can reference it.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "main" {
  name                = "appi-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

  # Workspace-based mode routes all telemetry into the Log Analytics
  # workspace above, so you query logs and app traces from one place.
  workspace_id = azurerm_log_analytics_workspace.main.id
}
