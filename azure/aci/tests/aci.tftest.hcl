# Credential-free tests: every provider is mocked, so no Azure or Twingate API is called.
# Run: terraform init -backend=false && terraform test

# azurerm parses resource IDs passed between resources, so mocked IDs must be well formed
mock_provider "azurerm" {
  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
    }
  }

  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/private"
    }
  }

  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip"
    }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/natGateways/nat"
    }
  }

  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/privateDnsZones/tg-tf-demo.int"
    }
  }

  mock_resource "azurerm_container_group" {
    defaults = {
      ip_address = "10.44.10.4"
    }
  }
}

mock_provider "twingate" {}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(azurerm_container_group.connector) == 2 && length(twingate_connector_tokens.this) == 2
    error_message = "Expected two Connector container groups, one token pair each, by default."
  }

  assert {
    condition     = alltrue([for g in azurerm_container_group.connector : g.ip_address_type == "Private" && g.dns_name_label == null])
    error_message = "Connector container groups must be private (no public IP or DNS label)."
  }

  assert {
    condition = alltrue([for g in azurerm_container_group.connector : (
      !contains(keys(g.container[0].environment_variables), "TWINGATE_ACCESS_TOKEN") &&
      !contains(keys(g.container[0].environment_variables), "TWINGATE_REFRESH_TOKEN")
    )])
    error_message = "Connector tokens must not be plain environment variables."
  }

  assert {
    condition     = one(azurerm_subnet.private.delegation[*].service_delegation[0].name) == "Microsoft.ContainerInstance/containerGroups"
    error_message = "Private subnet must be delegated to ACI."
  }

  assert {
    condition     = azurerm_subnet.private.default_outbound_access_enabled == false
    error_message = "Private subnet must egress only through the NAT gateway."
  }

  assert {
    condition     = alltrue([for g in azurerm_container_group.connector : length(g.image_registry_credential) == 0])
    error_message = "No registry credential unless azure_aci_registry_username is set."
  }

  assert {
    condition     = azurerm_container_group.private_resource.ip_address_type == "Private"
    error_message = "Private resource must not get a public IP."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-aci.tg-tf-demo.int"
    error_message = "Resource address should be the Private DNS FQDN."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    tg_connector_count          = 3
    azure_aci_registry_username = "example"
    azure_aci_registry_password = "example-pat"
    tg_create_service_account   = true
    tg_security_policy_name     = "Example Policy"
  }

  assert {
    condition     = length(azurerm_container_group.connector) == 3 && length(twingate_connector_tokens.this) == 3
    error_message = "Expected one container group per token pair."
  }

  assert {
    condition = alltrue([for i, g in azurerm_container_group.connector : (
      g.container[0].secure_environment_variables["TWINGATE_ACCESS_TOKEN"] == twingate_connector_tokens.this[i].access_token &&
      g.container[0].secure_environment_variables["TWINGATE_REFRESH_TOKEN"] == twingate_connector_tokens.this[i].refresh_token
    )])
    error_message = "Each Connector must receive its own tokens via secure_environment_variables."
  }

  assert {
    condition     = alltrue([for g in azurerm_container_group.connector : one(g.image_registry_credential[*].server) == "index.docker.io"])
    error_message = "Docker Hub credentials expected when azure_aci_registry_username is set."
  }

  assert {
    condition     = length(azurerm_network_security_group.private.security_rule) == 0
    error_message = "NSG must not add rules beyond the Azure defaults (no inbound from the internet)."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }
}

run "registry_password_required" {
  command = plan

  variables {
    azure_aci_registry_username = "example"
  }

  expect_failures = [azurerm_container_group.connector]
}
