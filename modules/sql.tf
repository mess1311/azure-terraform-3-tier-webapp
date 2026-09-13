# sql.tf
#
# WHAT THIS FILE DOES:
# Creates the Azure SQL Server + Database with NO public network access,
# reachable only through a Private Endpoint inside snet-data. Maps to
# Step 4 of the portal guide.

resource "azurerm_mssql_server" "main" {
  name                = "sql-3tier-${var.unique_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "12.0"

  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  # This is the setting that keeps the database off the public internet
  # entirely - the only way in is the private endpoint below.
  public_network_access_enabled = false

  minimum_tls_version = "1.2"
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-3tier"
  server_id = azurerm_mssql_server.main.id

  sku_name    = "Basic"
  max_size_gb = 2
}

# --- Private DNS zone ---
# This is what makes "yourserver.database.windows.net" resolve to the
# private endpoint's internal IP (10.0.3.x) instead of a public IP, but
# only for things querying DNS from inside this VNet.
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-vnet-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

# --- Private Endpoint ---
# Gives the SQL server an actual network interface with a private IP
# inside snet-data. The `private_dns_zone_group` nested block here is what
# automatically creates the DNS record in the zone above - you don't need
# a separate azurerm_private_dns_a_record resource for this.
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-3tier-${var.unique_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.data.id

  private_service_connection {
    name                           = "pe-connection-sql"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

# --- Connection string, assembled from the pieces above ---
# `local` values are like variables, but computed FROM other resources/
# expressions rather than supplied by the user. This one isn't marked
# sensitive by itself - see the NOTE in outputs.tf about why the password
# inside it still needs care.
locals {
  sql_connection_string = "Server=tcp:${azurerm_mssql_server.main.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.main.name};User ID=${var.sql_admin_login};Password=${var.sql_admin_password};Encrypt=true;TrustServerCertificate=false;Connection Timeout=30;"
}
