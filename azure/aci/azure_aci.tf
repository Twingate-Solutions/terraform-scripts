##############################################################
#
# Subnet Delegation & Registry Credentials
#
##############################################################

locals {
  # VNet-injected container groups need a subnet delegated to ACI
  private_subnet_delegation = {
    service = "Microsoft.ContainerInstance/containerGroups"
    actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
  }

  # Authenticated Docker Hub pulls avoid ACI deploy/restart failures on rate limits
  registry_credentials = var.azure_aci_registry_username == null ? [] : [{
    username = var.azure_aci_registry_username
    password = var.azure_aci_registry_password
  }]
}

##############################################################
#
# Twingate Connectors (one container group per Connector)
#
##############################################################

# Tokens are passed as secure_environment_variables, so they are not
# returned by the ACI API or shown in the portal. A token change
# replaces the container group (destroy, then create), so one token
# pair never runs in two places.
resource "azurerm_container_group" "connector" {
  count = var.tg_connector_count

  name                = "${var.app_name}-connector-${count.index + 1}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.private.id]
  tags                = local.common_tags

  dynamic "image_registry_credential" {
    for_each = local.registry_credentials
    content {
      server   = "index.docker.io"
      username = image_registry_credential.value.username
      password = image_registry_credential.value.password
    }
  }

  container {
    name   = "twingate-connector"
    image  = var.tg_connector_image
    cpu    = var.azure_aci_connector_cpu
    memory = var.azure_aci_connector_memory

    # ACI requires a port on a Private IP group. Nothing listens on it;
    # Connectors are outbound-only (same placeholder as Twingate's Azure guide).
    ports {
      port     = 9999
      protocol = "UDP"
    }

    environment_variables = {
      TWINGATE_NETWORK           = var.tg_network
      TWINGATE_LOG_ANALYTICS     = var.tg_log_analytics_version
      TWINGATE_LOG_LEVEL         = var.tg_log_level
      TWINGATE_LABEL_DEPLOYED_BY = "terraform-azure-aci"
    }

    secure_environment_variables = {
      TWINGATE_ACCESS_TOKEN  = twingate_connector_tokens.this[count.index].access_token
      TWINGATE_REFRESH_TOKEN = twingate_connector_tokens.this[count.index].refresh_token
    }
  }

  lifecycle {
    precondition {
      condition     = var.azure_aci_registry_username == null || var.azure_aci_registry_password != null
      error_message = "azure_aci_registry_username requires azure_aci_registry_password."
    }
  }

  # Container groups need the NAT path in place to pull the image
  depends_on = [
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_subnet_network_security_group_association.private,
  ]
}

##############################################################
#
# Private Resource (nginx container group, private IP only)
#
##############################################################

resource "azurerm_container_group" "private_resource" {
  name                = "${var.app_name}-resource"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Private"
  subnet_ids          = [azurerm_subnet.private.id]
  tags                = local.common_tags

  container {
    name   = "web"
    image  = "mcr.microsoft.com/azurelinux/base/nginx:1"
    cpu    = 0.5
    memory = 0.5

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  depends_on = [
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_subnet_network_security_group_association.private,
  ]
}

##############################################################
#
# Azure Private DNS (FQDN for the private resource)
#
##############################################################

# Container groups use Azure-provided DNS by default, which resolves
# Private DNS zones linked to the VNet.
resource "azurerm_private_dns_zone" "this" {
  name                = var.azure_dns_zone_name
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                = "${var.app_name}-vnet-link"
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  virtual_network_id  = azurerm_virtual_network.this.id
  tags                = local.common_tags
}

resource "azurerm_private_dns_a_record" "private_resource" {
  name                = "web-aci"
  private_dns_zone_id = azurerm_private_dns_zone.this.id
  ttl                 = 300
  records             = [azurerm_container_group.private_resource.ip_address]
  tags                = local.common_tags
}
