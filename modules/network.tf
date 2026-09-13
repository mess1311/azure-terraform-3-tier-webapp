# network.tf
#
# WHAT THIS FILE DOES:
# Creates the resource group, VNet, 4 subnets, and one NSG per subnet.
# This is the Terraform equivalent of Steps 1-3 in the portal guide.
#
# KEY CONCEPT - REFERENCES CREATE DEPENDENCIES:
# Notice below that the subnet resource writes:
#     resource_group_name = azurerm_resource_group.main.name
# instead of typing the string "rg-3tier-webapp-tf" again. Whenever one
# resource references another resource's attribute like this, Terraform
# automatically figures out it must create the resource_group FIRST, before
# the vnet. You never have to manually order things or write "wait for X" -
# Terraform builds this dependency graph for you from these references.

# --- Resource Group ---
# `resource "TYPE" "LOCAL_NAME" { ... }` is the basic shape of every
# resource block. "azurerm_resource_group" is the TYPE (defined by the
# provider). "main" is a LOCAL_NAME you choose - it's how you refer to
# this specific resource elsewhere in your code (azurerm_resource_group.main).
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# --- Network Security Groups ---
# One per tier. Each NSG is just a container for rules; it does nothing
# until it's associated with a subnet (that association happens further
# down in separate azurerm_subnet_network_security_group_association blocks -
# this is a deliberate Terraform design choice: NSGs and subnets are
# created independently, then linked, rather than nested like in the portal).

resource "azurerm_network_security_group" "gateway" {
  name                = "nsg-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Application Gateway v2 REQUIRES inbound access from the GatewayManager
  # service tag on ports 65200-65535 for its own control-plane traffic.
  # Skipping this is the #1 cause of "Gateway backend shows unhealthy".
  security_rule {
    name                       = "Allow-GatewayManager-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internet-HTTP-HTTPS-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer-Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Only the gateway subnet may reach the web tier.
  security_rule {
    name                       = "Allow-From-Gateway"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Only the web subnet may reach the app tier.
  security_rule {
    name                       = "Allow-From-Web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-data"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Only the app subnet may reach the data tier, and only on the SQL port.
  security_rule {
    name                       = "Allow-SQL-From-App"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
}

# --- Virtual Network ---
resource "azurerm_virtual_network" "main" {
  name                = "vnet-3tier"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

# --- Subnets ---
# Unlike the portal (where subnets are nested inside the VNet blade) or
# Bicep (where subnets are an inline array on the vnet resource),
# Terraform's azurerm provider models each subnet as its OWN resource that
# references the VNet by ID. This is a common pattern in Terraform: things
# that feel like "one thing" in the portal are often several linked
# resources here.

resource "azurerm_subnet" "gateway" {
  name                 = "snet-gateway"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  # App Service Regional VNet Integration requires the subnet to be
  # "delegated" to Microsoft.Web/serverFarms. Delegation basically tells
  # Azure "only App Service Plans are allowed to use this subnet in this
  # special way" - it's a prerequisite, not optional, for VNet integration.
  delegation {
    name = "webAppDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "appAppDelegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]

  # Required so Private Endpoints (used by the SQL database) can be
  # created inside this subnet.
  private_endpoint_network_policies = "Disabled"
}

# --- NSG <-> Subnet associations ---
# This is the "linking" step mentioned above: each association resource
# is its own block, taking a subnet_id and an nsg_id. There's no "parent"
# relationship here in Terraform's eyes - just two resources pointed at
# each other by a third, tiny resource whose only job is the association.

resource "azurerm_subnet_network_security_group_association" "gateway" {
  subnet_id                 = azurerm_subnet.gateway.id
  network_security_group_id = azurerm_network_security_group.gateway.id
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}
