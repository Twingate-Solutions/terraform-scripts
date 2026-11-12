##############################################################
#
# Locals
#
##############################################################

locals {
  # AKS node subnets cannot be delegated
  private_subnet_delegation = null

  # Split "<repository>:<tag>" for the Helm chart's image values
  connector_image = regex("^(?P<repository>.+):(?P<tag>[^:/]+)$", var.tg_connector_image)

  # The chart maps logLevel names to TWINGATE_LOG_LEVEL 3/4/6/7
  connector_log_level = {
    "3" = "error"
    "4" = "warning"
    "6" = "info"
    "7" = "debug"
  }[var.tg_log_level]

  connector_pod_label = { "app.kubernetes.io/part-of" = "twingate-connector" }
}

##############################################################
#
# AKS Cluster (system pool in the private subnet, NAT egress)
#
##############################################################

# Bring-your-own subnet: the cluster identity needs Network Contributor
# on the subnet before the cluster is created, so a user-assigned
# identity is used instead of a system-assigned one.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.app_name}-aks-identity"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_role_assignment" "aks_subnet" {
  scope                = azurerm_subnet.private.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
  principal_type       = "ServicePrincipal"
}

# Role assignments take time to propagate; creating the cluster straight
# after the grant can fail the subnet permission check on first apply.
# Replaced (and waits again) if the role assignment is replaced.
resource "time_sleep" "aks_subnet_role_propagation" {
  create_duration = "60s"

  triggers = {
    role_assignment_id = azurerm_role_assignment.aks_subnet.id
  }
}

locals {
  # NAT egress IP is added whenever ranges are set, so nodes can still reach the API server
  aks_api_authorized_ip_ranges = length(var.azure_aks_api_authorized_ip_ranges) == 0 ? toset([]) : setunion(
    var.azure_aks_api_authorized_ip_ranges,
    ["${azurerm_public_ip.nat.ip_address}/32"],
  )
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.app_name}-aks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${var.app_name}-aks"
  kubernetes_version  = var.azure_aks_kubernetes_version
  sku_tier            = "Free"
  tags                = local.common_tags

  default_node_pool {
    name                        = "system"
    vm_size                     = var.azure_aks_node_vm_size
    node_count                  = var.azure_aks_node_count
    vnet_subnet_id              = azurerm_subnet.private.id
    zones                       = length(var.azure_zones) == 0 ? null : var.azure_zones
    temporary_name_for_rotation = "systemtmp"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Nodes have private IPs only; egress uses the subnet's NAT gateway
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    outbound_type       = "userAssignedNATGateway"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  # Public API server by default; set azure_aks_api_authorized_ip_ranges to restrict it
  dynamic "api_server_access_profile" {
    for_each = length(var.azure_aks_api_authorized_ip_ranges) == 0 ? [] : [local.aks_api_authorized_ip_ranges]
    content {
      authorized_ip_ranges = api_server_access_profile.value
    }
  }

  # userAssignedNATGateway requires the NAT gateway on the subnet before creation
  depends_on = [
    time_sleep.aks_subnet_role_propagation,
    azurerm_subnet_nat_gateway_association.private,
    azurerm_nat_gateway_public_ip_association.this,
    azurerm_subnet_network_security_group_association.private,
  ]
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.azure_aks_namespace
  }
}

##############################################################
#
# Twingate Connectors (one Helm release per Connector)
#
##############################################################

# One release = one Deployment with one replica = one token pair.
# The chart stores the tokens in a Kubernetes Secret (set_sensitive keeps
# them out of plan output). Preferred anti-affinity spreads releases
# across zones, then nodes. The chart hard-codes
# TWINGATE_LABEL_DEPLOYED_BY=helm, so a separate label records this module.
resource "helm_release" "connector" {
  count = var.tg_connector_count

  name       = "twingate-connector-${count.index + 1}"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "https://twingate.github.io/helm-charts"
  chart      = "connector"
  version    = var.tg_helm_chart_version

  values = [yamlencode({
    image = {
      repository = local.connector_image.repository
      tag        = local.connector_image.tag
    }
    connector = {
      network      = var.tg_network
      logLevel     = local.connector_log_level
      logAnalytics = var.tg_log_analytics_version
    }
    env = {
      TWINGATE_LABEL_TERRAFORM_MODULE = "terraform-azure-aks"
    }
    additionalLabels = local.connector_pod_label
    affinity = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              labelSelector = { matchLabels = local.connector_pod_label }
              topologyKey   = "topology.kubernetes.io/zone"
            }
          },
          {
            weight = 50
            podAffinityTerm = {
              labelSelector = { matchLabels = local.connector_pod_label }
              topologyKey   = "kubernetes.io/hostname"
            }
          },
        ]
      }
    }
  })]

  set_sensitive = [
    {
      name  = "connector.accessToken"
      value = twingate_connector_tokens.this[count.index].access_token
    },
    {
      name  = "connector.refreshToken"
      value = twingate_connector_tokens.this[count.index].refresh_token
    },
  ]
}

##############################################################
#
# Private Resource (nginx Deployment + ClusterIP Service)
#
##############################################################

resource "kubernetes_deployment_v1" "private_resource" {
  metadata {
    name      = "web-aks"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "web-aks" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "web-aks" }
    }

    template {
      metadata {
        labels = { app = "web-aks" }
      }

      spec {
        container {
          name  = "web"
          image = "mcr.microsoft.com/azurelinux/base/nginx:1"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
        }
      }
    }
  }
}

# ClusterIP only: reachable inside the cluster, so only via the in-cluster Connectors
resource "kubernetes_service_v1" "private_resource" {
  metadata {
    name      = "web-aks"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = { app = "web-aks" }

    port {
      port        = 80
      target_port = 80
    }
  }
}
