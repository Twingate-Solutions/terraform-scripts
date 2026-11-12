# Credential-free tests: every provider is mocked, so no Azure, Kubernetes or Twingate API is called.
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

  # ip_address feeds api_server_access_profile.authorized_ip_ranges (CIDR-validated)
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip"
      ip_address = "203.0.113.10"
    }
  }

  mock_resource "azurerm_nat_gateway" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/natGateways/nat"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks"
      principal_id = "11111111-1111-1111-1111-111111111111"
    }
  }

  # kube_config feeds the kubernetes/helm provider blocks; mocks leave computed lists empty
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      kube_config = [{
        host                   = "https://tg-tf-demo-aks.hcp.eastus.azmk8s.io:443"
        client_certificate     = "bW9jaw=="
        client_key             = "bW9jaw=="
        cluster_ca_certificate = "bW9jaw=="
      }]
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

mock_provider "time" {}

mock_provider "twingate" {}

variables {
  tg_network = "example"
}

run "defaults_plan" {
  command = plan

  assert {
    condition     = length(helm_release.connector) == 2 && length(twingate_connector_tokens.this) == 2
    error_message = "Expected one Helm release per Connector token pair."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : r.repository == "https://twingate.github.io/helm-charts" && r.chart == "connector"])
    error_message = "Connectors must use the Twingate connector chart."
  }

  assert {
    condition = alltrue([for r in helm_release.connector : (
      !strcontains(r.values[0], "accessToken") && !strcontains(r.values[0], "refreshToken") &&
      yamldecode(r.values[0]).connector.network == "example" &&
      yamldecode(r.values[0]).image.tag == "1"
    )])
    error_message = "Tokens must not be in plain Helm values; network and image tag must be set."
  }

  # The chart hard-codes DEPLOYED_BY=helm, so the module is recorded in a separate label
  assert {
    condition     = alltrue([for r in helm_release.connector : yamldecode(r.values[0]).env.TWINGATE_LABEL_TERRAFORM_MODULE == "terraform-azure-aks"])
    error_message = "Connector releases must set TWINGATE_LABEL_TERRAFORM_MODULE."
  }

  assert {
    condition     = [for r in helm_release.connector : r.name] == ["twingate-connector-1", "twingate-connector-2"]
    error_message = "Release names must be twingate-connector-<n>."
  }

  assert {
    condition     = time_sleep.aks_subnet_role_propagation.create_duration == "60s"
    error_message = "Cluster creation must wait for the subnet role assignment to propagate."
  }

  assert {
    condition     = output.kubernetes_namespace == "tg-tf-demo"
    error_message = "kubernetes_namespace output must report the demo namespace."
  }

  assert {
    condition     = alltrue([for r in helm_release.connector : toset([for s in r.set_sensitive : s.name]) == toset(["connector.accessToken", "connector.refreshToken"])])
    error_message = "Tokens must be passed with set_sensitive."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].outbound_type == "userAssignedNATGateway"
    error_message = "Cluster egress must use the subnet's NAT gateway."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 2 && toset(azurerm_kubernetes_cluster.this.default_node_pool[0].zones) == toset(["1", "2", "3"])
    error_message = "Expected a two-node system pool across zones by default."
  }

  assert {
    condition     = length(azurerm_subnet.private.delegation) == 0 && azurerm_subnet.private.default_outbound_access_enabled == false
    error_message = "AKS node subnet must not be delegated and must egress only through the NAT gateway."
  }

  assert {
    condition     = azurerm_role_assignment.aks_subnet.role_definition_name == "Network Contributor"
    error_message = "Cluster identity needs Network Contributor on the BYO subnet."
  }

  assert {
    condition     = kubernetes_service_v1.private_resource.spec[0].type == "ClusterIP"
    error_message = "Demo service must not be exposed outside the cluster."
  }

  assert {
    condition     = twingate_resource.private_resource.address == "web-aks.tg-tf-demo.svc.cluster.local"
    error_message = "Resource address should be the in-cluster Service FQDN."
  }
}

run "apply_with_options" {
  command = apply

  variables {
    tg_connector_count        = 3
    tg_log_level              = "7"
    azure_zones               = []
    tg_create_service_account = true
    tg_existing_group_ids     = ["R3JvdXA6MQ=="]
  }

  assert {
    condition = alltrue([for i, r in helm_release.connector : (
      one([for s in r.set_sensitive : s.value if s.name == "connector.accessToken"]) == twingate_connector_tokens.this[i].access_token &&
      one([for s in r.set_sensitive : s.value if s.name == "connector.refreshToken"]) == twingate_connector_tokens.this[i].refresh_token
    )])
    error_message = "Each Helm release must carry its own token pair."
  }

  assert {
    condition     = length(distinct(helm_release.connector[*].name)) == 3
    error_message = "Release names must be unique per Connector."
  }

  assert {
    condition     = yamldecode(helm_release.connector[0].values[0]).connector.logLevel == "debug"
    error_message = "tg_log_level 7 must map to the chart's debug log level."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].zones == null
    error_message = "No zones when azure_zones is empty."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].node_public_ip_enabled != true
    error_message = "Nodes (and so the Connector pods) must not get public IPs."
  }

  assert {
    condition     = azurerm_role_assignment.aks_subnet.scope == azurerm_subnet.private.id
    error_message = "Network Contributor must be scoped to the node subnet."
  }

  assert {
    condition     = length(twingate_resource.private_resource.access_group) == 2 && length(twingate_resource.private_resource.access_service) == 1
    error_message = "Expected demo group, one existing group and the service account."
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.this.api_server_access_profile) == 0
    error_message = "API server must not be restricted unless azure_aks_api_authorized_ip_ranges is set."
  }
}

run "api_authorized_ip_ranges" {
  command = apply

  variables {
    azure_aks_api_authorized_ip_ranges = ["198.51.100.0/24", "192.0.2.7/32"]
  }

  assert {
    condition = (
      toset(azurerm_kubernetes_cluster.this.api_server_access_profile[0].authorized_ip_ranges) ==
      toset(["198.51.100.0/24", "192.0.2.7/32", "203.0.113.10/32"])
    )
    error_message = "Authorized IP ranges (plus the NAT egress IP) must land on the cluster."
  }
}

run "invalid_api_authorized_ip_range" {
  command = plan

  variables {
    azure_aks_api_authorized_ip_ranges = ["203.0.113.10"]
  }

  expect_failures = [var.azure_aks_api_authorized_ip_ranges]
}

run "invalid_log_level" {
  command = plan

  variables {
    tg_log_level = "5"
  }

  expect_failures = [var.tg_log_level]
}
