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

  mock_resource "azurerm_network_interface" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkInterfaces/nic"
      private_ip_address = "10.43.10.4"
    }
  }

  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/privateDnsZones/tg-tf-demo.int"
    }
  }
}

mock_provider "tls" {}

mock_provider "twingate" {}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(azurerm_linux_virtual_machine.connector) == 2 && length(twingate_connector_tokens.this) == 2
    error_message = "Expected two Connector VMs, one token pair each, by default."
  }

  assert {
    condition     = alltrue([for n in azurerm_network_interface.connector : alltrue([for c in n.ip_configuration : c.public_ip_address_id == null])])
    error_message = "Connector NICs must not have public IPs."
  }

  assert {
    condition     = [for v in azurerm_linux_virtual_machine.connector : v.zone] == ["1", "2"]
    error_message = "Connectors should be spread across zones."
  }

  assert {
    condition     = azurerm_subnet.private.default_outbound_access_enabled == false && length(azurerm_subnet.private.delegation) == 0
    error_message = "Private subnet must disable default outbound access and carry no delegation."
  }

  assert {
    condition     = length(tls_private_key.admin) == 1
    error_message = "A throwaway admin key is generated when azure_ssh_public_key is null."
  }

  assert {
    condition     = azurerm_resource_group.this.name == "tg-tf-demo-azure-vm-rg"
    error_message = "Resource group name should be unique per module."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-vm.tg-tf-demo.int"
    error_message = "Resource address should be the Private DNS FQDN."
  }

  assert {
    condition     = length(twingate_service_account.this) == 0 && length(data.twingate_security_policy.this) == 0
    error_message = "Service account and policy lookup must be off by default."
  }

  assert {
    condition = (
      strcontains(base64decode(azurerm_linux_virtual_machine.private_resource.custom_data), "DPkg::Lock::Timeout=300") &&
      strcontains(base64decode(azurerm_linux_virtual_machine.private_resource.custom_data), "for attempt in")
    )
    error_message = "nginx install must retry and wait for dpkg locks."
  }
}

run "apply_with_options" {
  command = apply

  # azure_ssh_public_key is a throwaway test key: the provider validates key format even under mocks
  variables {
    tg_connector_count        = 3
    azure_zones               = []
    azure_ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDVQblhs1VejgkZ1UkOglZ3jDfcy3OeUa+se43q5wFF tftest"
    tg_security_policy_name   = "Example Policy"
    tg_create_service_account = true
    tg_existing_group_ids     = ["R3JvdXA6MQ==", "R3JvdXA6Mg=="]
  }

  assert {
    condition     = length(twingate_connector_tokens.this) == 3 && length(azurerm_linux_virtual_machine.connector) == 3
    error_message = "Expected one token pair per Connector VM."
  }

  assert {
    condition     = alltrue([for v in azurerm_linux_virtual_machine.connector : v.zone == null])
    error_message = "No zones when azure_zones is empty."
  }

  assert {
    condition     = length(tls_private_key.admin) == 0
    error_message = "No key is generated when azure_ssh_public_key is set."
  }

  # security_rule is computed, so this can only be checked after apply
  assert {
    condition     = length(azurerm_network_security_group.private.security_rule) == 0
    error_message = "NSG must not add rules beyond the Azure defaults (no inbound from the internet)."
  }

  assert {
    condition     = strcontains(base64decode(azurerm_linux_virtual_machine.connector[2].custom_data), twingate_connector_tokens.this[2].access_token)
    error_message = "Each Connector VM must boot with its own token pair."
  }

  # Install retries as a unit and fails the cloud-init run if the config never lands
  assert {
    condition = alltrue([for v in azurerm_linux_virtual_machine.connector : (
      strcontains(base64decode(v.custom_data), "for attempt in") &&
      strcontains(base64decode(v.custom_data), "Twingate Connector install failed\"; exit 1") &&
      strcontains(base64decode(v.custom_data), "TWINGATE_LABEL_DEPLOYED_BY=\"terraform-azure-vm\"")
    )])
    error_message = "Connector install must retry, exit non-zero on failure and set the deployed-by label."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_group) == 3
    error_message = "Expected demo group plus two existing groups."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected service account access."
  }
}
