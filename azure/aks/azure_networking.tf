##############################################################
#
# Shared Azure networking (kept in sync across azure/* modules)
#
# Resource group, VNet, one private subnet with an NSG, and a
# NAT gateway for private-subnet egress. Each module sets
# local.private_subnet_delegation ({ service, actions } or null).
#
# Azure NAT Gateway picks a random SNAT port per connection
# (endpoint-dependent mapping), so Twingate peer-to-peer from
# Connectors behind it falls back to Relay. See README Notes.
#
##############################################################

locals {
  # Unique per module so azure/* modules can share a subscription
  resource_group_name = "${var.app_name}-${lower(replace(local.deployment, " ", "-"))}-rg"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.azure_location
  tags     = local.common_tags
}

##############################################################
#
# VNet & Private Subnet
#
##############################################################

resource "azurerm_virtual_network" "this" {
  name                = "${var.app_name}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.azure_vnet_cidr_block]
  tags                = local.common_tags
}

resource "azurerm_subnet" "private" {
  name                 = "${var.app_name}-private"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [cidrsubnet(var.azure_vnet_cidr_block, 8, 10)]

  # Egress only through the NAT gateway below
  default_outbound_access_enabled = false

  dynamic "delegation" {
    for_each = local.private_subnet_delegation == null ? [] : [local.private_subnet_delegation]
    content {
      name = "delegation"

      service_delegation {
        name    = delegation.value.service
        actions = delegation.value.actions
      }
    }
  }
}

##############################################################
#
# Network Security Group
#
##############################################################

# No custom rules: the Azure defaults allow inbound from the VNet and
# the Azure load balancer only, deny inbound from the internet, and
# allow all outbound. Connectors need outbound only.
resource "azurerm_network_security_group" "private" {
  name                = "${var.app_name}-private-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private.id
}

##############################################################
#
# NAT Gateway (private-subnet egress)
#
##############################################################

resource "azurerm_public_ip" "nat" {
  name                = "${var.app_name}-nat-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "this" {
  name                = "${var.app_name}-nat"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  subnet_id      = azurerm_subnet.private.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}
