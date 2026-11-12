##############################################################
#
# GKE Node Subnet (GKE-only: needs Pod and Service ranges)
#
# Nodes get their own subnet so the shared gcp_networking.tf
# stays identical across gcp/* modules. Cloud NAT covers all
# subnets and secondary ranges; the allow-internal firewall
# rule covers every range below (all inside the VPC plan).
#
##############################################################

resource "google_compute_subnetwork" "gke" {
  name                     = "${local.name_prefix}-nodes"
  region                   = var.gcp_region
  network                  = google_compute_network.this.id
  ip_cidr_range            = cidrsubnet(var.gcp_vpc_cidr_block, 8, 20) # nodes,    x.x.20.0/24
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = cidrsubnet(var.gcp_vpc_cidr_block, 2, 1) # pods,     x.x.64.0/18
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = cidrsubnet(var.gcp_vpc_cidr_block, 4, 2) # services, x.x.32.0/20
  }
}

##############################################################
#
# Node Service Account
#
##############################################################

# Dedicated least-privilege node identity instead of the Compute Engine default service account
resource "google_service_account" "nodes" {
  account_id   = "${local.name_prefix}-nodes"
  display_name = "${var.app_name} ${local.deployment} nodes"
}

resource "google_project_iam_member" "nodes" {
  project = var.gcp_project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = google_service_account.nodes.member
}

##############################################################
#
# GKE Standard Cluster (regional control plane, private nodes)
#
##############################################################

resource "google_container_cluster" "this" {
  name                = local.name_prefix
  location            = var.gcp_region
  node_locations      = local.zones
  network             = google_compute_network.this.id
  subnetwork          = google_compute_subnetwork.gke.id
  networking_mode     = "VPC_NATIVE"
  deletion_protection = false
  resource_labels     = local.common_labels

  # The node pool is managed separately below. Needed for GKE versions before
  # 1.36.4-gke.1469000, which cannot create a cluster without a default pool.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = var.gcp_gke_release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.gke.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.gke.secondary_ip_range[1].range_name
  }

  # Nodes have internal IPs only (egress via Cloud NAT). The control plane keeps a
  # public endpoint so Terraform can install the Helm releases from outside the VPC.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.gcp_gke_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.gcp_gke_authorized_networks
        content {
          cidr_block   = cidr_blocks.value
          display_name = "authorized-${cidr_blocks.key + 1}"
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  # No legacy client certificates (GKE default); Terraform authenticates with an OAuth token
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "this" {
  name       = "${local.name_prefix}-pool"
  cluster    = google_container_cluster.this.name
  location   = google_container_cluster.this.location
  node_count = var.gcp_gke_nodes_per_zone

  node_config {
    machine_type    = var.gcp_gke_machine_type
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    resource_labels = local.common_labels

    boot_disk {
      size_gb = 50
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Hide the node service account from Pods (Workload Identity metadata server)
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Private nodes pull images from Docker Hub through Cloud NAT
  depends_on = [google_project_iam_member.nodes, google_compute_router_nat.this]
}

##############################################################
#
# Twingate Connectors (one Helm release per Connector)
#
##############################################################

# Depends on the node pool so Kubernetes objects are deleted before the nodes on destroy
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.gcp_gke_namespace
  }

  depends_on = [google_container_node_pool.this]
}

locals {
  # The chart takes log level names, not TWINGATE_LOG_LEVEL numbers
  chart_log_level = {
    "3" = "error"
    "4" = "warning"
    "6" = "info"
    "7" = "debug"
  }[var.tg_log_level]

  # Split "<repository>:<tag>" for the Helm chart's image values
  connector_image = regex("^(?P<repository>.+):(?P<tag>[^:/]+)$", var.tg_connector_image)
}

# Values verified against Twingate/helm-charts stable/connector (chart 0.1.35):
# image.{repository,tag}, connector.{network,logLevel,logAnalytics,accessToken,refreshToken},
# env, affinity. The chart creates a Secret for the tokens and hard-codes
# TWINGATE_LABEL_DEPLOYED_BY=helm, so a separate label records this module instead of
# adding a duplicate env entry.
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
      logLevel     = local.chart_log_level
      logAnalytics = var.tg_log_analytics_version
    }

    env = {
      TWINGATE_LABEL_TERRAFORM_MODULE = "terraform-gcp-gke"
    }

    # Prefer placing each Connector in a different zone (one pod per release)
    affinity = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              topologyKey = "topology.kubernetes.io/zone"
              labelSelector = {
                matchLabels = { "app.kubernetes.io/name" = "connector" }
              }
            }
          },
        ]
      }
    }
  })]

  # Tokens stay out of the plain values list
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
    name      = "web-gke"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "web-gke" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "web-gke" }
    }

    template {
      metadata {
        labels = { app = "web-gke" }
      }

      spec {
        container {
          name  = "web"
          image = "nginx:stable-alpine"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "private_resource" {
  metadata {
    name      = "web-gke"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = { app = "web-gke" }

    port {
      port        = 80
      target_port = 80
    }
  }
}
